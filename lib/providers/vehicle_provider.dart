import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/firestore_paths.dart';

class VehicleProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> vehicles = [];
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vehiclesSubscription;

  VehicleProvider() {
    listenToAllVehicles();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    errorMessage = value;
    notifyListeners();
  }

  void _bindQuery(Query<Map<String, dynamic>> query) {
    _vehiclesSubscription?.cancel();
    _setLoading(true);
    _setError(null);

    _vehiclesSubscription = query.snapshots().listen(
      (snapshot) {
        vehicles = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _setLoading(false);
      },
      onError: (error) {
        vehicles = [];
        _setError(error.toString());
        _setLoading(false);
      },
    );
  }

  void listenToAllVehicles() {
    final query = _db
        .collection(FirestorePaths.vehicles)
        .orderBy('createdAt', descending: true);

    _bindQuery(query);
  }

  void listenToPublishedVehicles() {
    final query = _db
        .collection(FirestorePaths.vehicles)
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true);

    _bindQuery(query);
  }

  void listenToMyVehicles() {
    final uid = currentUserId;
    if (uid == null) {
      vehicles = [];
      _setError('لا يوجد مستخدم مسجل');
      return;
    }

    final query = _db
        .collection(FirestorePaths.vehicles)
        .where('workerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    _bindQuery(query);
  }

  Future<void> addVehicle(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('لا يوجد مستخدم مسجل');
    }

    await _db.collection(FirestorePaths.vehicles).add({
      ...data,
      'workerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateVehicleStatus({
    required String vehicleId,
    required String status,
  }) async {
    await _db.collection(FirestorePaths.vehicles).doc(vehicleId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  int get pendingReviewCount =>
      vehicles.where((v) => (v['status'] ?? '') == 'pending').length;

  int get publishedCount =>
      vehicles.where((v) => (v['status'] ?? '') == 'published').length;

  int get rejectedCount =>
      vehicles.where((v) => (v['status'] ?? '') == 'rejected').length;

  @override
  void dispose() {
    _vehiclesSubscription?.cancel();
    super.dispose();
  }
}
