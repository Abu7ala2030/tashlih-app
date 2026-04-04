import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

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
      phoneController.text = (selectedVehicle['contactPhone'] ?? '').toString();
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

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خدمة الموقع غير مفعلة على الجهاز')),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض صلاحية الموقع')),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('صلاحية الموقع مرفوضة نهائيًا، فعّلها من إعدادات الجهاز'),
        ),
      );
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
        setState(() {
          _suggestions = results;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل البحث عن العنوان: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => isSearchingAddress = false);
        }
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل اختيار العنوان: $e')),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isGettingCurrentLocation = true);

    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        if (mounted) setState(() => isGettingCurrentLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final address = await AddressSearchService.instance.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _deliveryAddress = address;
        _deliveryLat = position.latitude;
        _deliveryLng = position.longitude;
        _deliveryPlaceId = null;
        addressSearchController.text = address;
        _suggestions = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل جلب الموقع الحالي: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isGettingCurrentLocation = false);
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مركبة محددة')),
      );
      return;
    }

    if (partNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم القطعة')),
      );
      return;
    }

    if (cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المدينة')),
      );
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم التواصل')),
      );
      return;
    }

    if (needsShipping &&
        (_deliveryAddress == null ||
            _deliveryAddress!.trim().isEmpty ||
            _deliveryLat == null ||
            _deliveryLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد عنوان التوصيل الفعلي أولًا'),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = context.watch<HomeProvider>().selectedVehicle;
    final uid = context.watch<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب قطعة'),
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
                    'المركبة المختارة: ${selectedVehicle['make'] ?? ''} ${selectedVehicle['model'] ?? ''} ${selectedVehicle['year'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'التشليح: ${(selectedVehicle['scrapyardName'] ?? 'غير محدد').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المدينة: ${(selectedVehicle['city'] ?? 'غير محدد').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _InputField(
            controller: partNameController,
            label: 'اسم القطعة',
            hint: 'مثال: باب أمامي يمين',
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: notesController,
            label: 'وصف إضافي',
            hint: 'أي تفاصيل تساعد في تحديد القطعة',
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: cityController,
            label: 'المدينة',
            hint: 'مثال: الدمام',
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: phoneController,
            label: 'رقم التواصل',
            hint: '05xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: needsShipping,
            onChanged: (value) {
              setState(() {
                needsShipping = value;
                if (!needsShipping) {
                  _suggestions = [];
                }
              });
            },
            title: const Text('أحتاج شحن للقطعة'),
            subtitle:
                const Text('فعّلها إذا كنت تريد توصيل القطعة إلى عنوانك'),
            contentPadding: EdgeInsets.zero,
          ),
          if (needsShipping) ...[
            const SizedBox(height: 14),
            const Text(
              'عنوان التوصيل',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
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

                            final isSelected =
                                _deliveryAddress != null &&
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
                hintText: 'ابحث عن عنوانك أو اختر موقعك الحالي',
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isGettingCurrentLocation ? null : _useCurrentLocation,
                icon: isGettingCurrentLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  isGettingCurrentLocation
                      ? 'جاري جلب موقعك الحالي...'
                      : 'استخدام موقعي الحالي',
                ),
              ),
            ),
            if (_deliveryAddress != null && _deliveryAddress!.trim().isNotEmpty) ...[
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
                    const Text(
                      'العنوان المحدد',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
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
                  : const Text('إرسال الطلب'),
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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