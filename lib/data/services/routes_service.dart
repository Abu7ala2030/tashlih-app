import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RoutesService {
  RoutesService._();

  static final RoutesService instance = RoutesService._();

  // تم تثبيت المفتاح مباشرة مؤقتًا لتفادي خطأ dart-define
  static const String _apiKey = 'AIzaSyCADmgFQlwAywKfu5JmXKLeuhnCRlVhcDY';

  static const String _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<RouteDetails> computeRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY غير مضاف');
    }

    final uri = Uri.parse(_endpoint);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'languageCode': 'ar',
        'units': 'METRIC',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل جلب المسار: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List<dynamic>? ?? []);

    if (routes.isEmpty) {
      throw Exception('لم يتم العثور على مسار');
    }

    final first = routes.first as Map<String, dynamic>;

    final distanceMeters = (first['distanceMeters'] as num?)?.toInt() ?? 0;
    final durationText = (first['duration'] ?? '0s').toString();

    final encodedPolyline =
        ((first['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] ?? '')
            .toString();

    final points = encodedPolyline.isEmpty
        ? <LatLng>[]
        : decodePolyline(encodedPolyline);

    return RouteDetails(
      distanceMeters: distanceMeters,
      durationText: durationText,
      polylinePoints: points,
    );
  }

  List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> polylineCoordinates = <LatLng>[];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;

      while (true) {
        final b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      while (true) {
        final b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylineCoordinates;
  }
}

class RouteDetails {
  final int distanceMeters;
  final String durationText;
  final List<LatLng> polylinePoints;

  const RouteDetails({
    required this.distanceMeters,
    required this.durationText,
    required this.polylinePoints,
  });

  double get distanceKm => distanceMeters / 1000.0;

  int get durationMinutes {
    final seconds = _parseDurationSeconds(durationText);
    return (seconds / 60).ceil();
  }

  String get etaLabel {
    final minutes = durationMinutes;
    if (minutes <= 1) return 'أقل من دقيقة';
    if (minutes < 60) return '$minutes دقيقة';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) return '$hours ساعة';
    return '$hours ساعة و$remainingMinutes دقيقة';
  }

  String get distanceLabel {
    if (distanceKm < 1) return '$distanceMeters م';
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  static int _parseDurationSeconds(String value) {
    final clean = value.trim().toLowerCase();
    if (!clean.endsWith('s')) return 0;

    final numberPart = clean.substring(0, clean.length - 1);
    return int.tryParse(numberPart) ?? 0;
  }
}
