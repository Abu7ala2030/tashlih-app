import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> addVehicle(Map<String, dynamic> data) async {
    await _db.collection('vehicles').add(data);
  }

  Stream<QuerySnapshot> getVehicles() {
    return _db.collection('vehicles').snapshots();
  }

  Future<void> addRequest(Map<String, dynamic> data) async {
    await _db.collection('requests').add(data);
  }

  Stream<QuerySnapshot> getRequests() {
    return _db.collection('requests').snapshots();
  }
}
