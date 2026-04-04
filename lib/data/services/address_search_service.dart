import 'dart:convert';

import 'package:http/http.dart' as http;

class AddressSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;

  const AddressSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });
}

class AddressDetails {
  final String placeId;
  final String formattedAddress;
  final double lat;
  final double lng;

  const AddressDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}

class AddressSearchService {
  AddressSearchService._();

  static final AddressSearchService instance = AddressSearchService._();

  /// أولوية المفتاح:
  /// 1) --dart-define=GOOGLE_MAPS_API_KEY
  /// 2) fallback ثابت مؤقتًا حتى لا يتعطل البحث أثناء الاختبار
  ///
  /// بعد اكتمال الاختبارات يمكنك إبقاء dart-define فقط وحذف fallback.
  static const String _fallbackApiKey =
      'AIzaSyCADmgFQlwAywKfu5JmXKLeuhnCRlVhcDY';

  static const String _envApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static String get _apiKey {
    final env = _envApiKey.trim();
    if (env.isNotEmpty) return env;
    return _fallbackApiKey.trim();
  }

  Future<List<AddressSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY غير مضاف. شغّل التطبيق باستخدام --dart-define أو أضف fallback key',
      );
    }

    final query = input.trim();
    if (query.isEmpty) return const [];

    final body = <String, dynamic>{
      'input': query,
      'languageCode': 'ar',
      'includedRegionCodes': ['SA'],
      'sessionToken':
          sessionToken ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (latitude != null && longitude != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': 30000.0,
        },
      };
    }

    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text.text,'
            'suggestions.placePrediction.structuredFormat.mainText.text,'
            'suggestions.placePrediction.structuredFormat.secondaryText.text',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل البحث عن العنوان: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = (json['suggestions'] as List<dynamic>? ?? []);

    return suggestions
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['placePrediction'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((prediction) {
      final structured =
          (prediction['structuredFormat'] as Map<String, dynamic>? ?? {});
      final mainText =
          ((structured['mainText'] as Map<String, dynamic>? ?? {})['text'] ?? '')
              .toString();
      final secondaryText = ((structured['secondaryText']
                  as Map<String, dynamic>? ??
              {})['text'] ??
          '')
          .toString();
      final fullText =
          ((prediction['text'] as Map<String, dynamic>? ?? {})['text'] ?? '')
              .toString();

      return AddressSuggestion(
        placeId: (prediction['placeId'] ?? '').toString(),
        primaryText: mainText,
        secondaryText: secondaryText,
        fullText: fullText,
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  Future<AddressDetails> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY غير مضاف. شغّل التطبيق باستخدام --dart-define أو أضف fallback key',
      );
    }

    final response = await http.get(
      Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'id,formattedAddress,location',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل جلب تفاصيل العنوان: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final location = (json['location'] as Map<String, dynamic>? ?? {});
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      throw Exception('لم يتم العثور على إحداثيات للموقع المحدد');
    }

    return AddressDetails(
      placeId: (json['id'] ?? placeId).toString(),
      formattedAddress: (json['formattedAddress'] ?? '').toString(),
      lat: lat,
      lng: lng,
    );
  }

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY غير مضاف. شغّل التطبيق باستخدام --dart-define أو أضف fallback key',
      );
    }

    final response = await http.get(
      Uri.parse(
        'https://geocode.googleapis.com/v4beta/geocode/location/'
        '$latitude,$longitude'
        '?languageCode=ar&regionCode=SA&key=$_apiKey',
      ),
      headers: const {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل جلب عنوان الموقع الحالي: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (json['results'] as List<dynamic>? ?? []);

    if (results.isEmpty) {
      return '$latitude, $longitude';
    }

    final first = results.first as Map<String, dynamic>;
    final formattedAddress =
        (first['formattedAddress'] ?? '').toString().trim();

    if (formattedAddress.isNotEmpty) return formattedAddress;
    return '$latitude, $longitude';
  }
}
