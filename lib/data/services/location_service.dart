import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._();

  LocationService._();

  StreamSubscription<Position>? _positionStream;

  /// 🔐 طلب الصلاحيات
  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 🚀 بدء إرسال الموقع
  Future<void> startTracking({
    required String workerId,
  }) async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    stopTracking(); // تأكد ما فيه Stream قديم

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // كل 10 متر
      ),
    ).listen((position) async {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// 🛑 إيقاف التتبع
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}