import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._();

  LocationService._();

  static const int _minUpdateIntervalSeconds = 4;
  static const double _minDistanceMeters = 12;

  StreamSubscription<Position>? _positionStream;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  double _degToRad(double degrees) => degrees * math.pi / 180.0;

  double _distanceMeters(Position a, Position b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);

    final value = sinLat * sinLat +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            sinLng *
            sinLng;

    final c = 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
    return earthRadius * c;
  }

  bool _shouldSend(Position position) {
    final now = DateTime.now();

    if (_lastSentPosition == null || _lastSentAt == null) {
      return true;
    }

    final secondsSinceLast = now.difference(_lastSentAt!).inSeconds;
    final movedDistance = _distanceMeters(_lastSentPosition!, position);

    if (movedDistance >= _minDistanceMeters) return true;
    if (secondsSinceLast >= _minUpdateIntervalSeconds && movedDistance >= 3) {
      return true;
    }

    return false;
  }

  Future<void> _sendDriverLocation({
    required String driverId,
    required Position position,
  }) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .set({
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'speed': position.speed,
      'accuracy': position.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _lastSentPosition = position;
    _lastSentAt = DateTime.now();
  }

  Future<void> startTracking({
    required String driverId,
  }) async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    stopTracking();

    _lastSentPosition = null;
    _lastSentAt = null;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      if (!_shouldSend(position)) return;

      try {
        await _sendDriverLocation(
          driverId: driverId,
          position: position,
        );
      } catch (_) {}
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastSentPosition = null;
    _lastSentAt = null;
  }
}
