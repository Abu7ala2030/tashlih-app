import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/payment_method_option.dart';
import 'firestore_paths.dart';

class PaymentSessionService {
  PaymentSessionService._();

  static final PaymentSessionService instance = PaymentSessionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _buildReference(String prefix) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final tail = now.microsecondsSinceEpoch.toString().substring(8);
    return '$prefix-$stamp-$tail';
  }

  Future<String> createPaymentSession({
    required String invoiceId,
    required PaymentMethodOption method,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final invoiceRef = _db.collection(FirestorePaths.invoices).doc(invoiceId);
    final invoiceSnap = await invoiceRef.get();

    if (!invoiceSnap.exists) {
      throw Exception('Invoice not found');
    }

    final invoice = invoiceSnap.data() ?? <String, dynamic>{};

    final amount = _asDouble(invoice['totalAmount']);
    if (amount <= 0) {
      throw Exception('Invoice amount must be greater than zero');
    }

    final requestId = (invoice['requestId'] ?? '').toString().trim();
    final customerId = (invoice['customerId'] ?? '').toString().trim();
    final workerId = (invoice['workerId'] ?? '').toString().trim();
    final currency = (invoice['currency'] ?? 'SAR').toString().trim();

    final sessionRef = _db.collection(FirestorePaths.paymentSessions).doc();
    final sessionReference = _buildReference('PAY');

    final batch = _db.batch();

    batch.set(sessionRef, {
      'invoiceId': invoiceId,
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'provider': method.providerCode(),
      'method': method.methodCode,
      'amount': amount,
      'currency': currency.isEmpty ? 'SAR' : currency,
      'status': 'initiated',
      'checkoutUrl': '',
      'providerReference': sessionReference,
      'createdBy': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(invoiceRef, {
      'paymentProvider': method.providerCode(),
      'paymentMethod': method.methodCode,
      'paymentSessionId': sessionRef.id,
      'paymentStatus': 'initiated',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (requestId.isNotEmpty) {
      final requestRef = _db.collection(FirestorePaths.requests).doc(requestId);
      batch.set(requestRef, {
        'paymentProvider': method.providerCode(),
        'paymentMethod': method.methodCode,
        'paymentSessionId': sessionRef.id,
        'paymentStatus': 'initiated',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    return sessionRef.id;
  }
}