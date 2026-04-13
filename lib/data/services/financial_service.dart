import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_paths.dart';

class FinancialService {
  FinancialService._();

  static final FinancialService instance = FinancialService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _buildInvoiceNumber() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final tail = now.microsecondsSinceEpoch.toString().substring(8);
    return 'INV-$y$m$d-$tail';
  }

  Future<String?> _findExistingInvoiceId(String requestId) async {
    final snapshot = await _db
        .collection(FirestorePaths.invoices)
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<String> createInvoiceForDeliveredRequest({
    required String requestId,
    double defaultCommissionPercent = 10,
  }) async {
    final existingInvoiceId = await _findExistingInvoiceId(requestId);
    if (existingInvoiceId != null) {
      return existingInvoiceId;
    }

    final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
    final requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
      throw Exception('Request not found');
    }

    final request = requestSnap.data() ?? <String, dynamic>{};
    final status = (request['status'] ?? '').toString().trim();

    if (status != 'delivered') {
      throw Exception('Invoice can only be created after delivery');
    }

    final subtotal = _asDouble(request['acceptedOfferPrice']);
    final shippingFee = _asDouble(request['shippingFee']);
    final discount = _asDouble(request['discountAmount']);
    final totalAmount = subtotal + shippingFee - discount;

    if (totalAmount <= 0) {
      throw Exception('Invoice total must be greater than zero');
    }

    final customerId = (request['customerId'] ?? '').toString().trim();
    final workerId = (request['workerId'] ?? '').toString().trim();
    final driverId = (request['assignedDriverId'] ?? '').toString().trim();
    final partName = (request['partName'] ?? '').toString().trim();
    final city = (request['city'] ?? '').toString().trim();
    final scrapyardName = (request['scrapyardName'] ?? '').toString().trim();
    final commissionEligible = (request['commissionEligible'] ?? false) == true;
    final commissionPercent = defaultCommissionPercent;
    final commissionAmount =
        commissionEligible ? (totalAmount * commissionPercent / 100) : 0.0;

    final invoiceRef = _db.collection(FirestorePaths.invoices).doc();
    final transactionRef =
        _db.collection(FirestorePaths.financialTransactions).doc();

    final invoiceNumber = _buildInvoiceNumber();
    final paymentStatus =
        (request['paymentStatus'] ?? 'unpaid').toString().trim().isEmpty
            ? 'unpaid'
            : (request['paymentStatus'] ?? 'unpaid').toString().trim();

    final batch = _db.batch();

    batch.set(invoiceRef, {
      'invoiceNumber': invoiceNumber,
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'driverId': driverId,
      'partName': partName,
      'city': city,
      'scrapyardName': scrapyardName,
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discountAmount': discount,
      'totalAmount': totalAmount,
      'currency': 'SAR',
      'status': paymentStatus,
      'commissionEligible': commissionEligible,
      'commissionPercent': commissionPercent,
      'commissionAmount': commissionAmount,
      'issuedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(transactionRef, {
      'type': 'request_sale',
      'requestId': requestId,
      'invoiceId': invoiceRef.id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'workerId': workerId,
      'driverId': driverId,
      'amount': totalAmount,
      'currency': 'SAR',
      'status': paymentStatus == 'paid' ? 'paid' : 'open',
      'description': 'Sale transaction for delivered request',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(requestRef, {
      'invoiceId': invoiceRef.id,
      'invoiceNumber': invoiceNumber,
      'financeStatus': 'invoiced',
      'paymentStatus': paymentStatus,
      'subtotalAmount': subtotal,
      'shippingFee': shippingFee,
      'discountAmount': discount,
      'finalAmount': totalAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    final commissionsSnapshot = await _db
        .collection(FirestorePaths.commissions)
        .where('requestId', isEqualTo: requestId)
        .get();

    if (commissionsSnapshot.docs.isEmpty &&
        commissionEligible &&
        workerId.isNotEmpty) {
      await _db.collection(FirestorePaths.commissions).add({
        'requestId': requestId,
        'invoiceId': invoiceRef.id,
        'invoiceNumber': invoiceNumber,
        'workerId': workerId,
        'saleAmount': totalAmount,
        'commissionBaseAmount': totalAmount,
        'commissionPercent': commissionPercent,
        'commissionAmount': commissionAmount,
        'commissionStatus': 'pending',
        'partName': partName,
        'city': city,
        'scrapyardName': scrapyardName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      for (final doc in commissionsSnapshot.docs) {
        await doc.reference.set({
          'invoiceId': invoiceRef.id,
          'invoiceNumber': invoiceNumber,
          'saleAmount': totalAmount,
          'commissionBaseAmount': totalAmount,
          'commissionPercent': commissionPercent,
          'commissionAmount': commissionAmount,
          'partName': partName,
          'city': city,
          'scrapyardName': scrapyardName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    return invoiceRef.id;
  }
}