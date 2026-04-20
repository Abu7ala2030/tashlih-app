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
    final driverId = (invoice['driverId'] ?? '').toString().trim();
    final currency = (invoice['currency'] ?? 'SAR').toString().trim();

    final sessionRef = _db.collection(FirestorePaths.paymentSessions).doc();
    final sessionReference = _buildReference('PAY');

    await sessionRef.set({
      'invoiceId': invoiceId,
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'driverId': driverId,
      'provider': method.providerCode(),
      'method': method.methodCode,
      'amount': amount,
      'currency': currency.isEmpty ? 'SAR' : currency,
      'status': 'initiated',
      'checkoutUrl': '',
      'providerReference': sessionReference,
      'providerSessionId': '',
      'providerOrderId': '',
      'errorMessage': '',
      'createdBy': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return sessionRef.id;
  }
}