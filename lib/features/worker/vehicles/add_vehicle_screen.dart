import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/storage_service.dart';
import '../../../providers/vehicle_provider.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final makeController = TextEditingController();
  final modelController = TextEditingController();
  final yearController = TextEditingController();
  final colorController = TextEditingController();
  final cityController = TextEditingController();
  final scrapyardNameController = TextEditingController();
  final descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;

  String selectedDamageType = 'front';
  final List<String> selectedParts = [];

  double? scrapyardLat;
  double? scrapyardLng;
  String? scrapyardGoogleMapsUrl;

  final List<String> allParts = const [
    'door',
    'mirror',
    'bumper',
    'tail_light',
    'rim',
    'engine',
    'gearbox',
    'dashboard',
    'seats',
    'screen',
  ];

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadWorkerDefaults();
  }

  @override
  void dispose() {
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    colorController.dispose();
    cityController.dispose();
    scrapyardNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerDefaults() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      scrapyardNameController.text =
          (data['scrapyardName'] ?? '').toString().trim();

      scrapyardGoogleMapsUrl =
          (data['scrapyardGoogleMapsUrl'] ?? '').toString().trim();

      final latValue = data['scrapyardLat'];
      final lngValue = data['scrapyardLng'];

      if (latValue is num) {
        scrapyardLat = latValue.toDouble();
      } else {
        scrapyardLat = double.tryParse(latValue?.toString() ?? '');
      }

      if (lngValue is num) {
        scrapyardLng = lngValue.toDouble();
      } else {
        scrapyardLng = double.tryParse(lngValue?.toString() ?? '');
      }

      if (cityController.text.trim().isEmpty) {
        cityController.text = (data['city'] ?? '').toString().trim();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _togglePart(String part) {
    setState(() {
      if (selectedParts.contains(part)) {
        selectedParts.remove(part);
      } else {
        selectedParts.add(part);
      }
    });
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;

    setState(() {
      _selectedImages.addAll(images.map((x) => File(x.path)));
    });
  }

  Future<List<String>> _uploadImages() async {
    final storage = StorageService();
    final folder = DateTime.now().millisecondsSinceEpoch.toString();
    final urls = <String>[];

    for (final file in _selectedImages) {
      final url = await storage.uploadVehicleImage(
        file: file,
        folderName: folder,
      );
      urls.add(url);
    }

    return urls;
  }

  String _locationText() {
    if (scrapyardLat == null || scrapyardLng == null) {
      return l10n.translate('scrapyard_location_not_updated');
    }
    return '${scrapyardLat!.toStringAsFixed(6)}, ${scrapyardLng!.toStringAsFixed(6)}';
  }

  Future<void> _submit() async {
    if (makeController.text.trim().isEmpty ||
        modelController.text.trim().isEmpty ||
        yearController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('complete_make_model_year_city')),
        ),
      );
      return;
    }

    if (scrapyardNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('enter_scrapyard_name')),
        ),
      );
      return;
    }

    if (scrapyardLat == null || scrapyardLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('update_scrapyard_location_first')),
        ),
      );
      return;
    }

    final year = int.tryParse(yearController.text.trim());
    if (year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('year_must_be_number')),
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('select_at_least_one_vehicle_image')),
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('no_authenticated_user')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final imageUrls = await _uploadImages();

      final vehicle = {
        'make': makeController.text.trim(),
        'model': modelController.text.trim(),
        'year': year,
        'color': colorController.text.trim(),
        'city': cityController.text.trim(),
        'damageType': selectedDamageType,
        'description': descriptionController.text.trim(),
        'visibleParts': selectedParts,
        'status': 'pending',
        'workerId': currentUser.uid,
        'listedByWorkerId': currentUser.uid,
        'scrapyardName': scrapyardNameController.text.trim(),
        'scrapyardLat': scrapyardLat,
        'scrapyardLng': scrapyardLng,
        'scrapyardGoogleMapsUrl': scrapyardGoogleMapsUrl ?? '',
        'scrapyardLocation': scrapyardGoogleMapsUrl ?? '',
        'media': imageUrls,
        'coverImage': imageUrls.first,
        'createdAtLocal': DateTime.now().toIso8601String(),
      };

      await context.read<VehicleProvider>().addVehicle(vehicle);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('vehicle_uploaded_successfully')),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('vehicle_upload_failed')}: $e'),
        ),
      );
    }
  }

  String _partLabel(String part) {
    switch (part) {
      case 'door':
        return l10n.translate('part_door');
      case 'mirror':
        return l10n.translate('part_mirror');
      case 'bumper':
        return l10n.translate('part_bumper');
      case 'tail_light':
        return l10n.translate('part_tail_light');
      case 'rim':
        return l10n.translate('part_rim');
      case 'engine':
        return l10n.translate('part_engine');
      case 'gearbox':
        return l10n.translate('part_gearbox');
      case 'dashboard':
        return l10n.translate('part_dashboard');
      case 'seats':
        return l10n.translate('part_seats');
      case 'screen':
        return l10n.translate('part_screen');
      default:
        return part;
    }
  }

  String _damageTypeLabel(String value) {
    switch (value) {
      case 'front':
        return l10n.translate('damage_front');
      case 'rear':
        return l10n.translate('damage_rear');
      case 'leftSide':
        return l10n.translate('damage_left_side');
      case 'rightSide':
        return l10n.translate('damage_right_side');
      case 'rollover':
        return l10n.translate('damage_rollover');
      case 'flood':
        return l10n.translate('damage_flood');
      case 'fire':
        return l10n.translate('damage_fire');
      case 'unknown':
        return l10n.translate('unknown');
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate('add_vehicle'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.translate('add_vehicle_subtitle'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1F2A37),
                              Color(0xFF171A1F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('quick_tip'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('vehicle_photography_tip'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isLoadingProfile)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: _SectionCard(
                          title: l10n.translate('vehicle_images'),
                          child: Column(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : _pickImages,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(l10n.translate('select_vehicle_images')),
                              ),
                              const SizedBox(height: 14),
                              if (_selectedImages.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        l10n.translate('no_images_selected_yet'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 110,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImages.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Image.file(
                                              _selectedImages[index],
                                              width: 110,
                                              height: 110,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: InkWell(
                                              onTap: _isSubmitting
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _selectedImages
                                                            .removeAt(index);
                                                      });
                                                    },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration:
                                                    const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: _SectionCard(
                          title: l10n.translate('vehicle_data'),
                          child: Column(
                            children: [
                              _InputField(
                                controller: makeController,
                                label: l10n.translate('make'),
                                hint: l10n.translate('make_hint'),
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: modelController,
                                label: l10n.translate('model'),
                                hint: l10n.translate('model_hint'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InputField(
                                      controller: yearController,
                                      label: l10n.translate('year'),
                                      hint: '2018',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InputField(
                                      controller: colorController,
                                      label: l10n.translate('color'),
                                      hint: l10n.translate('color_hint'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: cityController,
                                label: l10n.translate('city'),
                                hint: l10n.translate('city_hint'),
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: scrapyardNameController,
                                label: l10n.translate('scrapyard_name'),
                                hint: l10n.translate('scrapyard_name_hint'),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.translate('actual_scrapyard_location'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _locationText(),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                    ),
                                    if ((scrapyardGoogleMapsUrl ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          scrapyardGoogleMapsUrl!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.translate('update_location_from_profile_hint'),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  l10n.translate('damage_type'),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedDamageType,
                                items: [
                                  DropdownMenuItem(
                                    value: 'front',
                                    child: Text(_damageTypeLabel('front')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rear',
                                    child: Text(_damageTypeLabel('rear')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'leftSide',
                                    child: Text(_damageTypeLabel('leftSide')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rightSide',
                                    child: Text(_damageTypeLabel('rightSide')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rollover',
                                    child: Text(_damageTypeLabel('rollover')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'flood',
                                    child: Text(_damageTypeLabel('flood')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fire',
                                    child: Text(_damageTypeLabel('fire')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'unknown',
                                    child: Text(_damageTypeLabel('unknown')),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => selectedDamageType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: descriptionController,
                                label: l10n.translate('condition_description'),
                                hint: l10n.translate('condition_description_hint'),
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                        child: _SectionCard(
                          title: l10n.translate('visible_or_possible_parts'),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allParts.map((part) {
                              return FilterChip(
                                label: Text(_partLabel(part)),
                                selected: selectedParts.contains(part),
                                onSelected: _isSubmitting
                                    ? null
                                    : (_) => _togglePart(part),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(.08),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_isSubmitting || _isLoadingProfile)
                      ? null
                      : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.translate('submit_for_review')),
                ),
              ),
            ),
          ),
        ),
        if (_isSubmitting)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }
}