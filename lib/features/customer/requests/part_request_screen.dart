import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/services/address_search_service.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/home_provider.dart';
import '../../../providers/request_provider.dart';

class PartRequestScreen extends StatefulWidget {
  const PartRequestScreen({super.key});

  @override
  State<PartRequestScreen> createState() => _PartRequestScreenState();
}

class _PartRequestScreenState extends State<PartRequestScreen> {
  final partNameController = TextEditingController();
  final notesController = TextEditingController();
  final cityController = TextEditingController();
  final phoneController = TextEditingController();
  final addressSearchController = TextEditingController();

  bool needsShipping = true;
  bool isSubmitting = false;
  bool isGettingCurrentLocation = false;
  bool isSearchingAddress = false;

  Timer? _debounce;
  String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  List<AddressSuggestion> _suggestions = [];

  String? _deliveryAddress;
  double? _deliveryLat;
  double? _deliveryLng;
  String? _deliveryPlaceId;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    final selectedVehicle = context.read<HomeProvider>().selectedVehicle;
    if (selectedVehicle != null) {
      cityController.text = (selectedVehicle['city'] ?? '').toString();
      phoneController.text =
          (selectedVehicle['contactPhone'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    partNameController.dispose();
    notesController.dispose();
    cityController.dispose();
    phoneController.dispose();
    addressSearchController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack(l10n.translate('location_service_disabled'));
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showSnack(l10n.translate('location_permission_denied'));
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnack(l10n.translate('location_permission_denied_forever'));
      return false;
    }

    return true;
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        isSearchingAddress = false;
        _deliveryAddress = null;
        _deliveryLat = null;
        _deliveryLng = null;
        _deliveryPlaceId = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => isSearchingAddress = true);

      try {
        final results = await AddressSearchService.instance.autocomplete(
          value,
          sessionToken: _sessionToken,
        );

        print('ADDRESS_RESULTS_COUNT: ${results.length}');
        for (final item in results) {
          print(
            'ADDRESS_RESULT_ITEM: ${item.placeId} | ${item.primaryText} | ${item.fullText}',
          );
        }

        if (!mounted) return;
        setState(() {
          _suggestions = results;
        });

        if (results.isEmpty && mounted) {
          _showSnack('لم يتم العثور على نتائج للعنوان. جرّب كلمة مختلفة.');
        }
      } catch (e) {
        print('ADDRESS_SEARCH_UI_ERROR: $e');
        _showSnack('${l10n.translate('address_search_failed')}: $e');
      } finally {
        if (mounted) setState(() => isSearchingAddress = false);
      }
    });
  }

  Future<void> _selectSuggestion(AddressSuggestion suggestion) async {
    try {
      final details =
          await AddressSearchService.instance.getPlaceDetails(suggestion.placeId);

      if (!mounted) return;

      setState(() {
        _deliveryAddress = details.formattedAddress;
        _deliveryLat = details.lat;
        _deliveryLng = details.lng;
        _deliveryPlaceId = details.placeId;
        addressSearchController.text = details.formattedAddress;
        _suggestions = [];
        _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      });
    } catch (e) {
      print('SELECT_ADDRESS_UI_ERROR: $e');
      _showSnack('${l10n.translate('select_address_failed')}: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isGettingCurrentLocation = true);

    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) return;

      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw Exception(
          'تعذر تحديد الموقع الحالي. تأكد من تشغيل GPS ثم حاول مرة أخرى.',
        );
      }

      final address = await AddressSearchService.instance.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _deliveryAddress = address;
        _deliveryLat = position!.latitude;
        _deliveryLng = position.longitude;
        _deliveryPlaceId = null;
        addressSearchController.text = address;
        _suggestions = [];
      });
    } catch (e) {
      print('GET_LOCATION_UI_ERROR: $e');
      _showSnack('${l10n.translate('get_location_failed')}: $e');
    } finally {
      if (mounted) setState(() => isGettingCurrentLocation = false);
    }
  }

  void _applySavedAddress(Map<String, dynamic> item) {
    final address = (item['deliveryAddress'] ?? '').toString().trim();
    final lat = item['deliveryLat'];
    final lng = item['deliveryLng'];

    double? parsedLat;
    double? parsedLng;

    if (lat is num) {
      parsedLat = lat.toDouble();
    } else {
      parsedLat = double.tryParse(lat?.toString() ?? '');
    }

    if (lng is num) {
      parsedLng = lng.toDouble();
    } else {
      parsedLng = double.tryParse(lng?.toString() ?? '');
    }

    if (address.isEmpty || parsedLat == null || parsedLng == null) return;

    setState(() {
      _deliveryAddress = address;
      _deliveryLat = parsedLat;
      _deliveryLng = parsedLng;
      _deliveryPlaceId = (item['deliveryPlaceId'] ?? '').toString().trim().isEmpty
          ? null
          : (item['deliveryPlaceId'] ?? '').toString().trim();
      addressSearchController.text = address;
      _suggestions = [];
    });
  }

  Future<void> _submit() async {
    final selectedVehicle = context.read<HomeProvider>().selectedVehicle;

    if (selectedVehicle == null) {
      _showSnack(l10n.translate('no_vehicle_selected'));
      return;
    }

    if (partNameController.text.trim().isEmpty) {
      _showSnack(l10n.translate('enter_part_name'));
      return;
    }

    if (cityController.text.trim().isEmpty) {
      _showSnack(l10n.translate('enter_city'));
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      _showSnack(l10n.translate('enter_phone'));
      return;
    }

    if (needsShipping &&
        (_deliveryAddress == null ||
            _deliveryAddress!.trim().isEmpty ||
            _deliveryLat == null ||
            _deliveryLng == null)) {
      _showSnack(l10n.translate('select_delivery_address'));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await context.read<RequestProvider>().createRequestFromVehicle(
            vehicle: selectedVehicle,
            partName: partNameController.text.trim(),
            city: cityController.text.trim(),
            phone: phoneController.text.trim(),
            notes: notesController.text.trim(),
            needsShipping: needsShipping,
            deliveryAddress: needsShipping ? _deliveryAddress : null,
            deliveryLat: needsShipping ? _deliveryLat : null,
            deliveryLng: needsShipping ? _deliveryLng : null,
            deliveryPlaceId: needsShipping ? _deliveryPlaceId : null,
          );

      if (!mounted) return;
      _showSnack(l10n.translate('request_sent_success'));
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('${l10n.translate('request_failed')}: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = context.watch<HomeProvider>().selectedVehicle;
    final uid = context.watch<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('part_request')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selectedVehicle != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedVehicle['make'] ?? ''} ${selectedVehicle['model'] ?? ''} ${selectedVehicle['year'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.translate('city')}: ${(selectedVehicle['city'] ?? '').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          _InputField(
            controller: partNameController,
            label: l10n.translate('part_name'),
            hint: l10n.translate('part_name_hint'),
          ),

          const SizedBox(height: 12),

          _InputField(
            controller: notesController,
            label: l10n.translate('notes'),
            hint: l10n.translate('notes_hint'),
            maxLines: 3,
          ),

          const SizedBox(height: 12),

          _InputField(
            controller: cityController,
            label: l10n.translate('city'),
            hint: '',
          ),

          const SizedBox(height: 12),

          _InputField(
            controller: phoneController,
            label: l10n.translate('phone'),
            hint: '05xxxxxxxx',
          ),

          const SizedBox(height: 12),

          SwitchListTile(
            value: needsShipping,
            onChanged: (v) {
              setState(() {
                needsShipping = v;
                if (!needsShipping) {
                  _suggestions = [];
                }
              });
            },
            title: Text(l10n.translate('needs_shipping')),
            subtitle: Text(l10n.translate('shipping_description')),
            contentPadding: EdgeInsets.zero,
          ),

          if (needsShipping) ...[
            const SizedBox(height: 12),
            Text(
              l10n.translate('delivery_address'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            if (uid != null && uid.isNotEmpty)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(FirestorePaths.requests)
                    .where('customerId', isEqualTo: uid)
                    .where('needsShipping', isEqualTo: true)
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final unique = <String, Map<String, dynamic>>{};

                  for (final doc in docs) {
                    final data = doc.data();
                    final address =
                        (data['deliveryAddress'] ?? '').toString().trim();
                    if (address.isEmpty) continue;
                    unique.putIfAbsent(address, () => data);
                  }

                  final savedAddresses = unique.values.toList();

                  if (savedAddresses.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العناوين المحفوظة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: savedAddresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = savedAddresses[index];
                            final address =
                                (item['deliveryAddress'] ?? '').toString();

                            final isSelected = _deliveryAddress != null &&
                                _deliveryAddress == address;

                            return ChoiceChip(
                              label: Text(
                                address,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: isSelected,
                              onSelected: (_) => _applySavedAddress(item),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),

            TextField(
              controller: addressSearchController,
              onChanged: _onAddressChanged,
              decoration: InputDecoration(
                hintText: l10n.translate('search_address'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearchingAddress
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (addressSearchController.text.trim().isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                addressSearchController.clear();
                                _deliveryAddress = null;
                                _deliveryLat = null;
                                _deliveryLng = null;
                                _deliveryPlaceId = null;
                                _suggestions = [];
                              });
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            if (_suggestions.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withOpacity(.06), height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        suggestion.primaryText.isEmpty
                            ? suggestion.fullText
                            : suggestion.primaryText,
                      ),
                      subtitle: suggestion.secondaryText.isEmpty
                          ? null
                          : Text(suggestion.secondaryText),
                      onTap: () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    isGettingCurrentLocation ? null : _useCurrentLocation,
                icon: isGettingCurrentLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  isGettingCurrentLocation
                      ? l10n.translate('getting_location')
                      : l10n.translate('use_current_location'),
                ),
              ),
            ),

            if (_deliveryAddress != null &&
                _deliveryAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('delivery_address'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _deliveryAddress!,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.translate('send_request')),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}