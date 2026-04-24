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
    final query = input.trim();
    if (query.isEmpty) return const [];

    print('ADDRESS_SEARCH_QUERY: $query');

    try {
      final legacy = await _autocompleteLegacy(
        query,
        sessionToken: sessionToken,
      );

      print('LEGACY_RESULTS_COUNT: ${legacy.length}');

      if (legacy.isNotEmpty) return legacy;
    } catch (e) {
      print('LEGACY_AUTOCOMPLETE_ERROR: $e');
    }

    try {
      final newer = await _autocompleteNew(
        query,
        sessionToken: sessionToken,
        latitude: latitude,
        longitude: longitude,
      );

      print('NEW_RESULTS_COUNT: ${newer.length}');

      return newer;
    } catch (e) {
      print('NEW_AUTOCOMPLETE_ERROR: $e');
      rethrow;
    }
  }

  Future<List<AddressSuggestion>> _autocompleteLegacy(
    String query, {
    String? sessionToken,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': _apiKey,
        'language': 'ar',
        'components': 'country:sa',
        'sessiontoken':
            sessionToken ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    print('LEGACY_AUTOCOMPLETE_URL: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    print('LEGACY_AUTOCOMPLETE: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Legacy autocomplete HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();

    if (status == 'ZERO_RESULTS') return const [];

    if (status != 'OK') {
      throw Exception(
        'Legacy autocomplete failed: $status - ${(json['error_message'] ?? '').toString()}',
      );
    }

    final predictions = json['predictions'] as List<dynamic>? ?? [];

    return predictions.map((item) {
      final data = item as Map<String, dynamic>;
      final formatting =
          data['structured_formatting'] as Map<String, dynamic>? ?? {};

      return AddressSuggestion(
        placeId: (data['place_id'] ?? '').toString(),
        primaryText: (formatting['main_text'] ?? '').toString(),
        secondaryText: (formatting['secondary_text'] ?? '').toString(),
        fullText: (data['description'] ?? '').toString(),
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  Future<List<AddressSuggestion>> _autocompleteNew(
    String query, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  }) async {
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

    print('NEW_AUTOCOMPLETE_BODY: ${jsonEncode(body)}');

    final response = await http
        .post(
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
        )
        .timeout(const Duration(seconds: 12));

    print('NEW_AUTOCOMPLETE: ${response.statusCode} ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل البحث عن العنوان: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = json['suggestions'] as List<dynamic>? ?? [];

    return suggestions
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['placePrediction'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((prediction) {
      final structured =
          prediction['structuredFormat'] as Map<String, dynamic>? ?? {};

      final mainText =
          (structured['mainText'] as Map<String, dynamic>? ?? {})['text']
                  ?.toString() ??
              '';

      final secondaryText =
          (structured['secondaryText'] as Map<String, dynamic>? ?? {})['text']
                  ?.toString() ??
              '';

      final fullText =
          (prediction['text'] as Map<String, dynamic>? ?? {})['text']
                  ?.toString() ??
              '';

      return AddressSuggestion(
        placeId: (prediction['placeId'] ?? '').toString(),
        primaryText: mainText,
        secondaryText: secondaryText,
        fullText: fullText,
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  Future<AddressDetails> getPlaceDetails(String placeId) async {
    try {
      return await _getPlaceDetailsLegacy(placeId);
    } catch (e) {
      print('LEGACY_PLACE_DETAILS_ERROR: $e');
      return _getPlaceDetailsNew(placeId);
    }
  }

  Future<AddressDetails> _getPlaceDetailsLegacy(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': _apiKey,
        'language': 'ar',
        'fields': 'place_id,formatted_address,geometry',
      },
    );

    print('LEGACY_PLACE_DETAILS_URL: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    print('LEGACY_PLACE_DETAILS: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Legacy place details HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();

    if (status != 'OK') {
      throw Exception(
        'Legacy place details failed: $status - ${(json['error_message'] ?? '').toString()}',
      );
    }

    final result = json['result'] as Map<String, dynamic>? ?? {};
    final geometry = result['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};

    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      throw Exception('لم يتم العثور على إحداثيات للموقع المحدد');
    }

    return AddressDetails(
      placeId: (result['place_id'] ?? placeId).toString(),
      formattedAddress: (result['formatted_address'] ?? '').toString(),
      lat: lat,
      lng: lng,
    );
  }

  Future<AddressDetails> _getPlaceDetailsNew(String placeId) async {
    final response = await http
        .get(
          Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'id,formattedAddress,location',
          },
        )
        .timeout(const Duration(seconds: 12));

    print('NEW_PLACE_DETAILS: ${response.statusCode} ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل جلب تفاصيل العنوان: ${response.statusCode} - ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final location = json['location'] as Map<String, dynamic>? ?? {};

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
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$latitude,$longitude',
        'key': _apiKey,
        'language': 'ar',
        'region': 'sa',
      },
    );

    print('REVERSE_GEOCODE_URL: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    print('REVERSE_GEOCODE: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('فشل جلب عنوان الموقع الحالي: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();

    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception(
        'فشل جلب عنوان الموقع الحالي: $status - ${(json['error_message'] ?? '').toString()}',
      );
    }

    final results = json['results'] as List<dynamic>? ?? [];

    if (results.isEmpty) {
      return '$latitude, $longitude';
    }

    final first = results.first as Map<String, dynamic>;
    final formattedAddress =
        (first['formatted_address'] ?? '').toString().trim();

    return formattedAddress.isNotEmpty
        ? formattedAddress
        : '$latitude, $longitude';
  }
}