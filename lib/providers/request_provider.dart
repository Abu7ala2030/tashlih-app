import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/chat_service.dart';
import '../data/services/firestore_paths.dart';
import '../data/services/financial_service.dart';
import '../core/utils/app_logger.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> requests = [];
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _requestsSubscription;
  String _activeListener = 'none';

  RequestProvider();

  String? get currentUserId => _auth.currentUser?.uid;
  String get activeListener => _activeListener;

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    errorMessage = value;
    notifyListeners();
  }

  Future<void> stopListening({bool clear = false}) async {
    await _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _activeListener = 'none';

    if (clear) {
      requests = [];
      errorMessage = null;
      isLoading = false;
    }

    notifyListeners();
  }

  void _bindQuery(
    Query<Map<String, dynamic>> query, {
    required String listenerName,
  }) {
    _requestsSubscription?.cancel();
    _activeListener = listenerName;
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

  Future<String> _resolveActorName({
    String? actorId,
    String? fallbackRole,
  }) async {
    final uid = actorId ?? currentUserId;
    if (uid == null || uid.isEmpty) {
      return fallbackRole == 'system' ? 'System' : 'User';
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
        return 'Customer';
      case 'worker':
        return 'Worker';
      case 'driver':
        return 'Driver';
      case 'admin':
        return 'Admin';
      case 'system':
        return 'System';
      default:
        return 'User';
    }
  }

  Future<String?> _findPrimaryDriverId() async {
    final snapshot = await _db
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: 'driver')
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) return null;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isActive = data['isActive'];
      if (isActive == true || isActive == null) {
        return doc.id;
      }
    }

    return snapshot.docs.first.id;
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

    try {
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
    } catch (e) {
      AppLogger.i('Notification skipped: $e');
    }
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
    final currentBest = currentBestRaw is num ? currentBestRaw.toDouble() : 0.0;

    if (offerPrice > currentBest) {
      await requestRef.set({
        'bestOfferPrice': offerPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> markOffersAsSeen({required String requestId}) async {
    await _db.collection(FirestorePaths.requests).doc(requestId).set({
      'newOffersCount': 0,
      'offersSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

    _bindQuery(query, listenerName: 'all_requests');
  }

  void listenToMyRequests() {
    final uid = currentUserId;
    if (uid == null) {
      requests = [];
      _setError('No authenticated user');
      notifyListeners();
      return;
    }

    final query = _db
        .collection(FirestorePaths.requests)
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    _bindQuery(query, listenerName: 'customer_requests');
  }

  void listenToOpenRequests() {
    final query = _db.collection(FirestorePaths.requests);

    _requestsSubscription?.cancel();
    _activeListener = 'open_requests';
    _setLoading(true);
    _setError(null);

    _requestsSubscription = query.snapshots().listen(
      (snapshot) {
        final allowedStatuses = {
          'newRequest',
          'checkingAvailability',
          'available',
        };

        final items = snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            })
            .where((item) {
              final status = (item['status'] ?? '').toString();
              return allowedStatuses.contains(status);
            })
            .toList();

        DateTime readDate(dynamic value) {
          if (value is Timestamp) return value.toDate();
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        items.sort((a, b) {
          final aDate = readDate(a['createdAt']);
          final bDate = readDate(b['createdAt']);
          return bDate.compareTo(aDate);
        });

        requests = items;
        _setLoading(false);
      },
      onError: (error) {
        requests = [];
        _setError(error.toString());
        _setLoading(false);
      },
    );
  }

  void listenToWorkerRequests({bool includeOpenRequests = false}) {
    final uid = currentUserId;
    if (uid == null) {
      requests = [];
      _setError('لا يوجد مستخدم مسجل');
      notifyListeners();
      return;
    }

    if (!includeOpenRequests) {
      final query = _db
          .collection(FirestorePaths.requests)
          .where('workerId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true);

      _bindQuery(query, listenerName: 'worker_requests_assigned_only');
      return;
    }

    final query = _db
        .collection(FirestorePaths.requests)
        .where('listedByWorkerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true);

    _bindQuery(query, listenerName: 'worker_requests_listed_vehicle');
  }

  void listenToDriverRequests() {
    final uid = currentUserId;
    if (uid == null) {
      requests = [];
      _setError('No authenticated user');
      notifyListeners();
      return;
    }

    final query = _db
        .collection(FirestorePaths.requests)
        .where('assignedDriverId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true);

    _bindQuery(query, listenerName: 'driver_requests');
  }

  Future<void> addRequest(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No authenticated user');
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
      title: 'Request created',
      description: 'A new request was submitted by the customer.',
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
      throw Exception('No authenticated user');
    }

    final listedByWorkerId =
        (vehicle['listedByWorkerId'] ?? '').toString().trim();
    final vehicleWorkerId = (vehicle['workerId'] ?? '').toString().trim();
    final resolvedWorkerId =
        listedByWorkerId.isNotEmpty ? listedByWorkerId : vehicleWorkerId;

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
      'listedByWorkerId': resolvedWorkerId,
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
      title: 'Request created',
      description:
          'The request was created from a vehicle already listed in the app.',
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
      title: 'Worker assigned',
      description: 'The request was linked to the selected worker.',
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
      title: 'Driver assigned',
      description: 'The request was assigned to the driver for delivery.',
      actorId: currentUserId ?? '',
      actorRole: 'admin',
      extra: {'driverId': driverId},
    );

    await _sendUserNotification(
      userId: driverId,
      title: 'A new request was assigned to you',
      body: 'There is a new request waiting for pickup and delivery.',
      type: 'driver_assigned',
      requestId: requestId,
      dedupWithin: const Duration(hours: 12),
      extra: {'deliveryStatus': 'pending_pickup'},
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'A driver was assigned to your request',
        body: 'A driver has been assigned and pickup will start soon.',
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
      title: 'Status updated',
      description: 'The request status was changed to $status.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
      extra: {'status': status},
    );
  }

  Future<void> markDriverPickedUp({required String requestId}) async {
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
      title: 'Driver picked up the request',
      description: 'The request was picked up from the worker or scrapyard.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'Your request was picked up',
        body:
            'The driver picked up your request and it is being prepared for delivery.',
        type: 'driver_picked_up',
        requestId: requestId,
        dedupWithin: const Duration(hours: 6),
      );
    }
  }

  Future<void> markDriverOnTheWay({required String requestId}) async {
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
      title: 'Driver is on the way',
      description: 'The driver started delivery to the customer address.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'Driver is on the way',
        body: 'Your request is now on the way to you.',
        type: 'request_shipped',
        requestId: requestId,
        dedupWithin: const Duration(hours: 6),
      );
    }
  }

  Future<void> markDriverDelivered({required String requestId}) async {
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
      title: 'Request delivered',
      description: 'The driver confirmed successful delivery to the customer.',
      actorId: currentUserId ?? '',
      actorRole: 'driver',
    );

    final customerId = (requestData['customerId'] ?? '').toString();
    if (customerId.isNotEmpty) {
      await _sendUserNotification(
        userId: customerId,
        title: 'Your request was delivered',
        body: 'The driver confirmed successful delivery of your request.',
        type: 'request_delivered',
        requestId: requestId,
        dedupWithin: const Duration(hours: 12),
      );
    }

    await FinancialService.instance.createInvoiceForDeliveredRequest(
      requestId: requestId,
    );
  }

  Future<void> markRequestShipped({required String requestId}) async {
    final requestSnap = await _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();
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
      title: 'Request shipped',
      description: 'The part was shipped to the customer.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'Your request was shipped',
      body: 'The requested part was shipped and is now on the way to you.',
      type: 'request_shipped',
      requestId: requestId,
      dedupWithin: const Duration(hours: 6),
    );
  }

  Future<void> markRequestDelivered({required String requestId}) async {
    final requestSnap = await _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();
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
      title: 'Request delivered',
      description: 'The part was delivered successfully to the customer.',
      actorId: currentUserId ?? '',
      actorRole: 'worker',
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'Your request was delivered',
      body: 'The part for your request was delivered successfully.',
      type: 'request_delivered',
      requestId: requestId,
      dedupWithin: const Duration(hours: 12),
    );

    await FinancialService.instance.createInvoiceForDeliveredRequest(
      requestId: requestId,
    );
  }

  Future<void> submitOffer({
    required String requestId,
    required double price,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No authenticated user');
    }

    final requestSnap = await _db
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();
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
    await _updateBestOfferPrice(requestId: requestId, offerPrice: price);

    await _db.collection(FirestorePaths.requests).doc(requestId).set({
      'status': 'available',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimelineEvent(
      requestId: requestId,
      type: 'offer_submitted',
      title: 'Offer submitted',
      description: 'A new price offer was submitted for this request.',
      actorId: uid,
      actorRole: 'worker',
      extra: {'offerId': offerRef.id, 'price': price},
    );

    await _sendUserNotification(
      userId: customerId,
      title: 'New offer received',
      body: 'A new price offer was received for your request.',
      type: 'new_offer',
      requestId: requestId,
      secondaryId: offerRef.id,
      dedupWithin: const Duration(hours: 24),
      extra: {'offerId': offerRef.id, 'price': price},
    );
  }

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
    required String workerId,
  }) async {
    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final offerRef = requestRef.collection('offers').doc(offerId);

    final driverId = await _findPrimaryDriverId();

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      final offerSnap = await transaction.get(offerRef);

      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      if (!offerSnap.exists) {
        throw Exception('Offer not found');
      }

      final requestData = requestSnap.data() ?? {};
      final offerData = offerSnap.data() ?? {};

      final status = (requestData['status'] ?? '').toString();

      if (status == 'assigned' ||
          status == 'shipped' ||
          status == 'delivered' ||
          status == 'cancelled') {
        throw Exception('An offer has already been selected');
      }

      final acceptedOfferPrice = (offerData['price'] is num)
          ? (offerData['price'] as num).toDouble()
          : 0.0;

      final listedByWorkerId =
          (requestData['listedByWorkerId'] ?? '').toString();

      final commissionEligible =
          listedByWorkerId.isNotEmpty && listedByWorkerId == workerId;

      final updateData = <String, dynamic>{
        'workerId': workerId,
        'acceptedOfferId': offerId,
        'acceptedOfferPrice': acceptedOfferPrice,
        'commissionEligible': commissionEligible,
        'commissionBaseAmount': acceptedOfferPrice,
        'newOffersCount': 0,
        'bestOfferPrice': acceptedOfferPrice,
        'status': 'assigned',
        'deliveryStatus':
            driverId != null && driverId.isNotEmpty
                ? 'pending_pickup'
                : 'awaiting_driver_assignment',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (driverId != null && driverId.isNotEmpty) {
        updateData['assignedDriverId'] = driverId;
        updateData['driverAssignedAt'] = FieldValue.serverTimestamp();
      }

      transaction.update(requestRef, updateData);

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
    final assignedDriverId = (requestData['assignedDriverId'] ?? '').toString();

    try {
      await _addTimelineEvent(
        requestId: requestId,
        type: 'offer_accepted',
        title: 'Offer selected',
        description:
            'A price offer was accepted and the worker was assigned to the request.',
        actorId: currentUserId ?? '',
        actorRole: 'customer',
        extra: {
          'offerId': offerId,
          'workerId': workerId,
          'price': acceptedOfferPrice,
        },
      );
    } catch (e) {
      AppLogger.i('Offer accepted timeline skipped: $e');
    }

    try {
      await _sendUserNotification(
        userId: workerId,
        title: 'تم قبول عرضك',
        body: 'تم قبول عرضك على الطلب وبدء التنفيذ.',
        type: 'offer_accepted',
        requestId: requestId,
        secondaryId: offerId,
      );
    } catch (e) {
      AppLogger.i('Offer accepted notification skipped: $e');
    }

    try {
      await ChatService.instance.createOrGetChat(
        requestId: requestId,
        customerId: customerId,
        workerId: workerId,
      );
    } catch (e) {
      AppLogger.i('Create chat skipped after offer accepted: $e');
    }

    try {
      if (assignedDriverId.isNotEmpty) {
        await _addTimelineEvent(
          requestId: requestId,
          type: 'driver_assigned',
          title: 'Driver assigned',
          description: 'The request was assigned to the driver for delivery.',
          actorId: currentUserId ?? '',
          actorRole: 'system',
          extra: {'driverId': assignedDriverId},
        );

        await _sendUserNotification(
          userId: assignedDriverId,
          title: 'تم إسناد طلب جديد لك',
          body: 'يوجد طلب جديد بانتظار الاستلام والتوصيل.',
          type: 'driver_assigned',
          requestId: requestId,
          dedupWithin: const Duration(hours: 12),
          extra: {'deliveryStatus': 'pending_pickup'},
        );

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
      } else {
        await _addTimelineEvent(
          requestId: requestId,
          type: 'driver_assignment_pending',
          title: 'Waiting for driver assignment',
          description:
              'The offer was accepted, but there is no active driver account ready yet.',
          actorId: currentUserId ?? '',
          actorRole: 'system',
        );
      }
    } catch (e) {
      AppLogger.i('Driver post-accept steps skipped: $e');
    }

    try {
      if ((requestData['commissionEligible'] ?? false) == true) {
        const commissionPercent = 10.0;
        final commissionAmount = acceptedOfferPrice * commissionPercent / 100;

        await _db.collection(FirestorePaths.commissions).add({
          'requestId': requestId,
          'offerId': offerId,
          'workerId': workerId,
          'saleAmount': acceptedOfferPrice,
          'commissionBaseAmount': acceptedOfferPrice,
          'commissionPercent': commissionPercent,
          'commissionAmount': commissionAmount,
          'commissionStatus': 'pending',
          'partName': (requestData['partName'] ?? '').toString(),
          'city': (requestData['city'] ?? '').toString(),
          'scrapyardName': (requestData['scrapyardName'] ?? '').toString(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.i('Commission creation skipped after offer accepted: $e');
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

    final offerSnap = await offerRef.get();
    final offerData = offerSnap.data() ?? <String, dynamic>{};
    final workerId = (offerData['workerId'] ?? '').toString().trim();

    await offerRef.update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addTimelineEvent(
      requestId: requestId,
      type: 'offer_rejected',
      title: 'Offer rejected',
      description: 'One of the offers on this request was rejected.',
      actorId: currentUserId ?? '',
      actorRole: 'customer',
      extra: {'offerId': offerId},
    );

    if (workerId.isNotEmpty) {
      await _sendUserNotification(
        userId: workerId,
        title: 'Offer rejected',
        body: 'Unfortunately, your offer was rejected.',
        type: 'offer_rejected',
        requestId: requestId,
        secondaryId: offerId,
        dedupWithin: const Duration(hours: 12),
        extra: {'offerId': offerId},
      );
    }
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