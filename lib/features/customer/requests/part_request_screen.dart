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

  AppLocalizations get l10n => AppLocalizations.of(context);

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

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        isSearchingAddress = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => isSearchingAddress = true);

      try {
        final results = await AddressSearchService.instance.autocomplete(
          value,
          sessionToken: _sessionToken,
        );

        if (!mounted) return;
        setState(() => _suggestions = results);
      } catch (e) {
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
      });
    } catch (e) {
      _showSnack('${l10n.translate('select_address_failed')}: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isGettingCurrentLocation = true);

    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) return;

      final position = await Geolocator.getCurrentPosition();

      final address = await AddressSearchService.instance.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _deliveryAddress = address;
        _deliveryLat = position.latitude;
        _deliveryLng = position.longitude;
        addressSearchController.text = address;
        _suggestions = [];
      });
    } catch (e) {
      _showSnack('${l10n.translate('get_location_failed')}: $e');
    } finally {
      if (mounted) setState(() => isGettingCurrentLocation = false);
    }
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
            deliveryAddress: _deliveryAddress,
            deliveryLat: _deliveryLat,
            deliveryLng: _deliveryLng,
          );

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('part_request')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selectedVehicle != null)
            Text(
              '${selectedVehicle['make']} ${selectedVehicle['model']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
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

          SwitchListTile(
            value: needsShipping,
            onChanged: (v) => setState(() => needsShipping = v),
            title: Text(l10n.translate('needs_shipping')),
            subtitle: Text(l10n.translate('shipping_description')),
          ),

          if (needsShipping) ...[
            Text(l10n.translate('delivery_address')),
            const SizedBox(height: 8),

            TextField(
              controller: addressSearchController,
              onChanged: _onAddressChanged,
              decoration: InputDecoration(
                hintText: l10n.translate('search_address'),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: _useCurrentLocation,
              child: Text(
                isGettingCurrentLocation
                    ? l10n.translate('getting_location')
                    : l10n.translate('use_current_location'),
              ),
            ),
          ],

          const SizedBox(height: 20),

          FilledButton(
            onPressed: _submit,
            child: Text(l10n.translate('send_request')),
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

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }
}