import 'package:cloud_firestore/cloud_firestore.dart';

class RequestActionService {
  RequestActionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
    required String customerId,
  }) async {
    final requestRef = _firestore.collection('requests').doc(requestId);
    final offersRef = requestRef.collection('offers');

    await _firestore.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('الطلب غير موجود');
      }

      final requestData = requestSnap.data() as Map<String, dynamic>;

      final status = (requestData['status'] ?? 'open').toString();
      final isLocked = requestData['isLocked'] == true;
      final requestCustomerId = (requestData['customerId'] ?? '').toString();

      if (requestCustomerId != customerId) {
        throw Exception('غير مصرح لك بقبول هذا العرض');
      }

      if (status != 'open' || isLocked) {
        throw Exception('تم إغلاق الطلب بالفعل');
      }

      final offersQuery = await offersRef.get();
      final selectedOfferRef = offersRef.doc(offerId);

      DocumentSnapshot<Map<String, dynamic>>? selectedOfferSnap;
      for (final doc in offersQuery.docs) {
        if (doc.id == offerId) {
          selectedOfferSnap = doc;
          break;
        }
      }

      if (selectedOfferSnap == null || !selectedOfferSnap.exists) {
        throw Exception('العرض غير موجود');
      }

      final selectedOfferData = selectedOfferSnap.data()!;
      final selectedOfferStatus =
          (selectedOfferData['status'] ?? 'pending').toString();

      if (selectedOfferStatus != 'pending') {
        throw Exception('هذا العرض لم يعد متاحًا');
      }

      final workerId = (selectedOfferData['workerId'] ?? '').toString();
      final yardId = (selectedOfferData['yardId'] ?? '').toString();
      final price = selectedOfferData['price'];
      final workerName = (selectedOfferData['workerName'] ?? '').toString();
      final yardName = (selectedOfferData['yardName'] ?? '').toString();
      final phone = (selectedOfferData['phone'] ?? '').toString();

      final now = FieldValue.serverTimestamp();

      transaction.update(requestRef, {
        'status': 'accepted',
        'isLocked': true,
        'acceptedOfferId': offerId,
        'acceptedWorkerId': workerId,
        'acceptedYardId': yardId,
        'acceptedPrice': price,
        'acceptedAt': now,
        'closedAt': now,
        'updatedAt': now,

        // snapshot مفيد حتى لا تضيع البيانات لاحقًا
        'acceptedOfferSnapshot': {
          'offerId': offerId,
          'workerId': workerId,
          'yardId': yardId,
          'workerName': workerName,
          'yardName': yardName,
          'phone': phone,
          'price': price,
        },
      });

      for (final offerDoc in offersQuery.docs) {
        if (offerDoc.id == offerId) {
          transaction.update(offerDoc.reference, {
            'status': 'accepted',
            'decisionAt': now,
            'updatedAt': now,
          });
        } else {
          final currentStatus =
              (offerDoc.data()['status'] ?? 'pending').toString();

          if (currentStatus == 'pending') {
            transaction.update(offerDoc.reference, {
              'status': 'rejected',
              'decisionAt': now,
              'updatedAt': now,
            });
          }
        }
      }
    });
  }
}