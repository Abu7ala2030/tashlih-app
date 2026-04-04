import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/chat_service.dart';
import '../data/services/firestore_paths.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> requests = [];
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;

  RequestProvider() {
    listenToAllRequests();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> _resolveActorName({
    String? actorId,
    String? fallbackRole,
  }) async {
    final uid = actorId ?? currentUserId;
    if (uid == null || uid.isEmpty) {
      return fallbackRole == 'system' ? 'النظام' : 'مستخدم';
    }

    try {
      final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;

      final scrapyardName = (data['scrapyardName'] ?? '').toString().trim();
      if (scrapyardName.isNotEmpty) return scrapyardName;

      final phone = (data['phone'] ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;
    } catch (_) {}

    final authName = _auth.currentUser?.displayName?.trim() ?? '';
    if (authName.isNotEmpty && uid == currentUserId) return authName;

    switch (fallbackRole) {
      case 'customer':
        return 'العميل';
      case 'worker':
        return 'العامل';
      case 'driver':
        return 'السائق';
      case 'admin':
        return 'الإدارة';
      case 'system':
        return 'النظام';
      default:
        return 'مستخدم';
    }
  }

  String _notificationDedupKey({
    required String type,
    required String requestId,
    String? secondaryId,
  }) {
    final cleanSecondary = (secondaryId ?? '').trim();
    if (cleanSecondary.isNotEmpty) {
      return '${type}_${requestId}_$cleanSecondary';
    }
    return '${type}_$requestId';
  }

  Future<bool> _hasRecentDuplicateNotification({
    required String userId,
    required String dedupKey,
    Duration within = const Duration(minutes: 10),
  }) async {
    if (userId.trim().isEmpty || dedupKey.trim().isEmpty) return false;

    try {
      final cutoff = DateTime.now().subtract(within);

      final snapshot = await _db
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection('notifications')
          .where('dedupKey', isEqualTo: dedupKey)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
          )
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendUserNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String requestId,
    String? secondaryId,
    Duration dedupWithin = const Duration(minutes: 10),
    Map<String, dynamic>? extra,
  }) async {
    if (userId.trim().isEmpty) return;

    final dedupKey = _notificationDedupKey(
      type: type,
      requestId: requestId,
      secondaryId: secondaryId,
    );

    final isDuplicate = await _hasRecentDuplicateNotification(
      userId: userId,
      dedupKey: dedupKey,
      within: dedupWithin,
    );

    if (isDuplicate) return;

    await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'requestId': requestId,
      'dedupKey': dedupKey,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...?extra,
    });
  }

  Future<void> _incrementRequestNewOffersCounter({
    required String requestId,
  }) async {
    await _db.collection(FirestorePaths.requests).doc(requestId).set({
      'newOffersCount': FieldValue.increment(1),
      'lastOfferAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _updateBestOfferPrice({
    required String requestId,
    required double offerPrice,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final snap = await requestRef.get();
    final data = snap.data() ?? <String, dynamic>{};

    final currentBestRaw = data['bestOfferPrice'];
    final currentBest =
        currentBestRaw is num ? currentBestRaw.toDouble() : 0.0;

    if (offerPrice > currentBest) {
      await requestRef.set({
        'bestOfferPrice': offerPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> markOffersAsSeen({
    required String requestId,
  }) async {
    await _db.collection(FirestorePaths.requests).doc(requestId).set({
      'newOffersCount': 0,
      'offersSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    errorMessage = value;
    notifyListeners();
  }

  void _bindQuery(Query<Map<String, dynamic>> query) {
    _requestsSubscription?.cancel();
    _setLoading(true);
    _setError(null);

    _requestsSubscription = query.snapshots().listen(
      (snapshot) {
        requests = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _setLoading(false);
      },
      onError: (error) {
        requests = [];
        _setError(error.toString());
        _setLoading(false);
      },
    );
  }

  Future<void> _addTimelineEvent({
    required String requestId,
    required String type,
    required String title,
    required String description,
    String? actorId,
    String? actorRole,
    Map<String, dynamic>? extra,
  }) async {
    final resolvedActorId = actorId ?? currentUserId ?? '';
    final resolvedActorRole = actorRole ?? 'system';
    final actorName = await _resolveActorName(
      actorId: resolvedActorId,
      fallbackRole: resolvedActorRole,
    );

    await _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .collection('timeline')
        .add({
      'type': type,
      'title': title,
      'description': description,
      'actorId': resolvedActorId,
      'actorRole': resolvedActorRole,
      'actorName': actorName,
      'createdAt': FieldValue.serverTimestamp(),
      ...?extra,
    });
  }

  void listenToAllRequests() {
    final query = _db
        .collection(FirestorePaths.requests)
        .orderBy('createdAt', descending: true);

    _bindQuery(query);
  }

  void listenToMyRequests() {
    final uid = currentUserId;
    if (uid == null) {
      requests = [];
      _setError('لا يوجد مستخدم مسجل');
      notifyListeners();
      return;
    }

    final query = _db
        .collection(FirestorePaths.requests)
        .where('customerId', isEqualTo: uid);

    _bindQuery(query);
  }

  void listenToWorkerRequests() {
    final query = _db
        .collection(FirestorePaths.requests)
        .orderBy('createdAt', descending: true);

    _bindQuery(query);
  }

  Future<void> addRequest(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('لا يوجد مستخدم مسجل');
    }

    final ref = await _db.collection(FirestorePaths.requests).add({
      ...data,
      'customerId': uid,
      'status': data['status'] ?? 'newRequest',
      'newOffersCount': 0,
      'bestOfferPrice': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: ref.id,
      type: 'request_created',
      title: 'تم إنشاء الطلب',
      description: 'تم إرسال طلب جديد من العميل.',
      actorId: uid,
      actorRole: 'customer',
    );
  }

  Future<void> createRequestFromVehicle({
    required Map<String, dynamic> vehicle,
    required String partName,
    required String city,
    required String phone,
    String notes = '',
    bool needsShipping = true,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryPlaceId,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('لا يوجد مستخدم مسجل');
    }

    final ref = await _db.collection(FirestorePaths.requests).add({
      'customerId': uid,
      'vehicleId': (vehicle['id'] ?? '').toString(),
      'vehicleMake': (vehicle['make'] ?? '').toString(),
      'vehicleModel': (vehicle['model'] ?? '').toString(),
      'vehicleYear': vehicle['year'],
      'vehicleCoverImage': (vehicle['coverImage'] ?? '').toString(),
      'partName': partName,
      'city': city,
      'phone': phone,
      'notes': notes,
      'needsShipping': needsShipping,
      'deliveryAddress': deliveryAddress ?? '',
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'deliveryPlaceId': deliveryPlaceId ?? '',
      'listedByWorkerId': (vehicle['listedByWorkerId'] ?? '').toString(),
      'scrapyardName': (vehicle['scrapyardName'] ?? '').toString(),
      'scrapyardLocation': (vehicle['scrapyardLocation'] ?? '').toString(),
      'status': 'newRequest',
      'newOffersCount': 0,
      'bestOfferPrice': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: ref.id,
      type: 'request_created',
      title: 'تم إنشاء الطلب',
      description: 'تم إنشاء الطلب من مركبة موجودة في التطبيق.',
      actorId: uid,
      actorRole: 'customer',
      extra: {
        'partName': partName,
        'vehicleId': (vehicle['id'] ?? '').toString(),
        'deliveryAddress': deliveryAddress ?? '',
      },
    );
  }

  Future<void> assignRequestToWorker({
    required String requestId,
    required String workerId,
  }) async {
    await _db.collection(FirestorePaths.requests).doc(requestId).update({
      'workerId': workerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'worker_assigned',
      title: 'تم تعيين عامل',
      description: 'تم ربط الطلب بالعامل المحدد.',
      actorId: currentUserId ?? '',
      actorRole: 'admin',
      extra: {'workerId': workerId},
    );
  }

  Future<void> assignRequestToDriver({
    required String requestId,
    required String driverId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};

    await requestRef.set({
      'assignedDriverId': driverId,
      'deliveryStatus': 'pending_pickup',
      'driverAssignedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'driver_assigned',
      title: 'تم تعيين السائق',
      description: 'تم إسناد الطلب إلى السائق لمتابعة التوصيل.',
      actorId: currentUserId ?? '',
      actorRole: 'admin',
      extra: {'driverId': driverId},
    );

    await _sendUserNotification(
      userId: driverId,
      title: 'تم إسناد طلب جديد لك',
      body: 'يوجد طلب جديد بانتظار الاستلام والتوصيل.',
      type: 'driver_assigned',
      requestId: requestId,
      dedupWithin: const Duration(hours: 12),
      extra: {
        'deliveryStatus': 'pending_pickup',
      },
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'تم تعيين سائق للطلب',
        body: 'تم تعيين سائق لطلبك وسيبدأ الاستلام قريبًا.',
        type: 'driver_assigned_customer',
        requestId: requestId,
        dedupWithin: const Duration(hours: 12),
      );
    }
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    await _db.collection(FirestorePaths.requests).doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'status_changed',
      title: 'تم تحديث الحالة',
      description: 'تم تغيير حالة الطلب إلى $status.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
      extra: {'status': status},
    );
  }

  Future<void> markDriverPickedUp({
    required String requestId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};

    await requestRef.set({
      'deliveryStatus': 'picked_up',
      'pickedUpAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'driver_picked_up',
      title: 'استلم السائق الطلب',
      description: 'تم استلام الطلب من العامل أو التشليح.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'تم استلام الطلب',
        body: 'استلم السائق طلبك وجارٍ تجهيزه للتوصيل.',
        type: 'driver_picked_up',
        requestId: requestId,
        dedupWithin: const Duration(hours: 6),
      );
    }
  }

  Future<void> markDriverOnTheWay({
    required String requestId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};

    await requestRef.set({
      'deliveryStatus': 'on_the_way',
      'status': 'shipped',
      'shippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'driver_on_the_way',
      title: 'السائق في الطريق',
      description: 'بدأ السائق التوصيل إلى عنوان العميل.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'السائق في الطريق',
        body: 'طلبك الآن في الطريق إليك.',
        type: 'request_shipped',
        requestId: requestId,
        dedupWithin: const Duration(hours: 6),
      );
    }
  }

  Future<void> markDriverDelivered({
    required String requestId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};

    await requestRef.set({
      'deliveryStatus': 'delivered',
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'driver_delivered',
      title: 'تم التسليم',
      description: 'أكد السائق تسليم الطلب للعميل.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'تم تسليم الطلب',
        body: 'أكد السائق تسليم طلبك بنجاح.',
        type: 'request_delivered',
        requestId: requestId,
        dedupWithin: const Duration(hours: 12),
      );
    }
  }

  Future<void> markRequestShipped({
    required String requestId,
  }) async {
    final requestSnap =
        await _db.collection(FirestorePaths.requests).doc(requestId).get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};
    final customerId = (requestData['customerId'] ?? '').toString();

    await _db.collection(FirestorePaths.requests).doc(requestId).update({
      'status': 'shipped',
      'deliveryStatus': 'on_the_way',
      'shippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'shipped',
      title: 'تم شحن الطلب',
      description: 'تم شحن القطعة إلى العميل.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'تم شحن الطلب',
      body: 'تم شحن القطعة المطلوبة وهي الآن في الطريق إليك.',
      type: 'request_shipped',
      requestId: requestId,
      dedupWithin: const Duration(hours: 6),
    );
  }

  Future<void> markRequestDelivered({
    required String requestId,
  }) async {
    final requestSnap =
        await _db.collection(FirestorePaths.requests).doc(requestId).get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};
    final customerId = (requestData['customerId'] ?? '').toString();

    await _db.collection(FirestorePaths.requests).doc(requestId).update({
      'status': 'delivered',
      'deliveryStatus': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'delivered',
      title: 'تم التسليم',
      description: 'تم تسليم القطعة للعميل بنجاح.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'تم تسليم الطلب',
      body: 'تم تسليم القطعة الخاصة بطلبك بنجاح.',
      type: 'request_delivered',
      requestId: requestId,
      dedupWithin: const Duration(hours: 12),
    );
  }

  Future<void> submitOffer({
    required String requestId,
    required double price,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('لا يوجد مستخدم مسجل');
    }

    final requestSnap =
        await _db.collection(FirestorePaths.requests).doc(requestId).get();
    final requestData = requestSnap.data() ?? <String, dynamic>{};
    final customerId = (requestData['customerId'] ?? '').toString();

    final offerRef = _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .collection('offers')
        .doc();

    await offerRef.set({
      'workerId': uid,
      'price': price,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _incrementRequestNewOffersCounter(requestId: requestId);
    await _updateBestOfferPrice(
      requestId: requestId,
      offerPrice: price,
    );

    await _db.collection(FirestorePaths.requests).doc(requestId).set({
      'status': 'available',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'offer_submitted',
      title: 'تم تقديم عرض',
      description: 'تم إرسال عرض سعر جديد على الطلب.',
      actorId: uid,
      actorRole: 'worker',
      extra: {
        'offerId': offerRef.id,
        'price': price,
      },
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'وصل عرض جديد',
      body: 'تم استلام عرض سعر جديد على طلبك.',
      type: 'new_offer',
      requestId: requestId,
      secondaryId: offerRef.id,
      dedupWithin: const Duration(hours: 24),
      extra: {
        'offerId': offerRef.id,
        'price': price,
      },
    );
  }

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
    required String workerId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final offerRef = requestRef.collection('offers').doc(offerId);

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      final offerSnap = await transaction.get(offerRef);

      if (!requestSnap.exists) {
        throw Exception('الطلب غير موجود');
      }

      if (!offerSnap.exists) {
        throw Exception('العرض غير موجود');
      }

      final requestData = requestSnap.data() ?? {};
      final offerData = offerSnap.data() ?? {};

      final status = (requestData['status'] ?? '').toString();

      if (status == 'assigned' ||
          status == 'shipped' ||
          status == 'delivered' ||
          status == 'cancelled') {
        throw Exception('تم اختيار عرض مسبقًا');
      }

      final acceptedOfferPrice = (offerData['price'] is num)
          ? (offerData['price'] as num).toDouble()
          : 0.0;

      final listedByWorkerId =
          (requestData['listedByWorkerId'] ?? '').toString();

      final commissionEligible =
          listedByWorkerId.isNotEmpty && listedByWorkerId == workerId;

      transaction.update(requestRef, {
        'workerId': workerId,
        'acceptedOfferId': offerId,
        'acceptedOfferPrice': acceptedOfferPrice,
        'commissionEligible': commissionEligible,
        'commissionBaseAmount': acceptedOfferPrice,
        'newOffersCount': 0,
        'bestOfferPrice': acceptedOfferPrice,
        'status': 'assigned',
        'deliveryStatus': 'awaiting_driver_assignment',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(offerRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final offersSnap = await requestRef.collection('offers').get();

      for (final doc in offersSnap.docs) {
        if (doc.id != offerId) {
          transaction.update(doc.reference, {
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? {};

    final acceptedOfferPrice = (requestData['acceptedOfferPrice'] is num)
        ? (requestData['acceptedOfferPrice'] as num).toDouble()
        : 0.0;

    final customerId = (requestData['customerId'] ?? '').toString();

    await _addTimelineEvent(
      requestId: requestId,
      type: 'offer_accepted',
      title: 'تم اختيار العرض',
      description: 'تم قبول عرض سعر واعتماد العامل للطلب.',
      actorId: currentUserId ?? '',
      actorRole: 'customer',
      extra: {
        'offerId': offerId,
        'workerId': workerId,
        'price': acceptedOfferPrice,
      },
    );

    await _sendUserNotification(
      userId: workerId,
      title: 'تم قبول عرضك',
      body: 'تم قبول عرضك على الطلب وبدء التنفيذ.',
      type: 'offer_accepted',
      requestId: requestId,
      secondaryId: offerId,
    );

    await ChatService.instance.createOrGetChat(
      requestId: requestId,
      customerId: customerId,
      workerId: workerId,
    );

    if ((requestData['commissionEligible'] ?? false) == true) {
      await _db.collection(FirestorePaths.commissions).add({
        'requestId': requestId,
        'offerId': offerId,
        'workerId': workerId,
        'saleAmount': acceptedOfferPrice,
        'commissionBaseAmount': acceptedOfferPrice,
        'commissionStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    notifyListeners();
  }

  Future<void> rejectOffer({
    required String requestId,
    required String offerId,
  }) async {
    final offerRef = _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .collection('offers')
        .doc(offerId);

    await offerRef.update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'offer_rejected',
      title: 'تم رفض عرض',
      description: 'تم رفض أحد العروض على الطلب.',
      actorId: currentUserId ?? '',
      actorRole: 'customer',
      extra: {'offerId': offerId},
    );
  }

  int get pendingCount =>
      requests.where((r) => (r['status'] ?? '') == 'newRequest').length;

  int get checkingCount => requests
      .where((r) => (r['status'] ?? '') == 'checkingAvailability')
      .length;

  int get availableCount =>
      requests.where((r) => (r['status'] ?? '') == 'available').length;

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
