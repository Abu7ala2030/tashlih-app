import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../vehicles/add_vehicle_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController scrapyardNameController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool isGettingLocation = false;

  double? scrapyardLat;
  double? scrapyardLng;
  String? scrapyardGoogleMapsUrl;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    scrapyardNameController.dispose();
    super.dispose();
  }

  String? get _uid => _auth.currentUser?.uid;

  Future<void> _loadWorkerProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      nameController.text = (data['name'] ?? '').toString();
      phoneController.text = (data['phone'] ?? '').toString();
      scrapyardNameController.text = (data['scrapyardName'] ?? '').toString();

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

      scrapyardGoogleMapsUrl =
          (data['scrapyardGoogleMapsUrl'] ?? '').toString().trim();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('load_worker_data_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('location_service_disabled'))),
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
        SnackBar(content: Text(l10n.translate('location_permission_denied'))),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('worker_location_permission_denied_forever')),
        ),
      );
      return false;
    }

    return true;
  }

  String _buildGoogleMapsUrl(double lat, double lng) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  Future<void> _useCurrentLocation() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_authenticated_user'))),
      );
      return;
    }

    setState(() => isGettingLocation = true);

    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        if (mounted) setState(() => isGettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final mapsUrl = _buildGoogleMapsUrl(lat, lng);

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'role': 'worker',
        'scrapyardLat': lat,
        'scrapyardLng': lng,
        'scrapyardGoogleMapsUrl': mapsUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        scrapyardLat = lat;
        scrapyardLng = lng;
        scrapyardGoogleMapsUrl = mapsUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('actual_location_updated_successfully'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('get_location_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isGettingLocation = false);
      }
    }
  }

  Future<void> _saveWorkerProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_authenticated_user'))),
      );
      return;
    }

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_worker_name'))),
      );
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_phone_error'))),
      );
      return;
    }

    if (scrapyardNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_scrapyard_name'))),
      );
      return;
    }

    if (scrapyardLat == null || scrapyardLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('update_current_scrapyard_location_first'))),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final mapsUrl = _buildGoogleMapsUrl(scrapyardLat!, scrapyardLng!);

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'role': 'worker',
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'scrapyardName': scrapyardNameController.text.trim(),
        'scrapyardLat': scrapyardLat,
        'scrapyardLng': scrapyardLng,
        'scrapyardGoogleMapsUrl': mapsUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        scrapyardGoogleMapsUrl = mapsUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('worker_data_saved_successfully'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('save_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _openMapUrl() async {
    final url = (scrapyardGoogleMapsUrl ?? '').trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_saved_scrapyard_location'))),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('invalid_location_link'))),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('unable_to_open_location'))),
    );
  }

  Future<void> _openAddVehicle() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddVehicleScreen(),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('vehicle_added_successfully'))),
      );
    }
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('support'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.translate('worker_support_description'),
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApprovalStatusSheet({
    required int totalVehicles,
    required int pendingVehicles,
    required int publishedVehicles,
    required int rejectedVehicles,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.translate('approval_status'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _StatusInfoRow(
                  label: l10n.translate('total_vehicles'),
                  value: totalVehicles.toString(),
                ),
                _StatusInfoRow(
                  label: l10n.translate('pending_review'),
                  value: pendingVehicles.toString(),
                ),
                _StatusInfoRow(
                  label: l10n.translate('published'),
                  value: publishedVehicles.toString(),
                ),
                _StatusInfoRow(
                  label: l10n.translate('rejected'),
                  value: rejectedVehicles.toString(),
                  isLast: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.translate('latest_notifications'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('users')
                        .doc(uid)
                        .collection('notifications')
                        .orderBy('createdAt', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.translate('no_notifications'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final title =
                              (data['title'] ?? l10n.translate('notification')).toString();
                          final body = (data['body'] ?? '').toString();
                          final type = (data['type'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D21),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  body.isEmpty ? l10n.translate('no_details') : body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),
                                if (type.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      type,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('logout_failed')}: $e')),
      );
    }
  }

  String _locationText() {
    if (scrapyardLat == null || scrapyardLng == null) {
      return l10n.translate('location_not_set_yet');
    }
    return '${scrapyardLat!.toStringAsFixed(6)}, ${scrapyardLng!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    final uid = _uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : _db.collection('vehicles').where('workerId', isEqualTo: uid).snapshots(),
      builder: (context, vehicleSnapshot) {
        final vehicleDocs = vehicleSnapshot.data?.docs ?? [];
        final totalVehicles = vehicleDocs.length;
        final pendingVehicles = vehicleDocs
            .where((doc) => (doc.data()['status'] ?? '') == 'pending')
            .length;
        final publishedVehicles = vehicleDocs
            .where((doc) => (doc.data()['status'] ?? '') == 'published')
            .length;
        final rejectedVehicles = vehicleDocs
            .where((doc) => (doc.data()['status'] ?? '') == 'rejected')
            .length;

        return Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('worker_account'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('worker_account_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
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
                            colors: [Color(0xFF1D3557), Color(0xFF171A1F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.badge_outlined, size: 34),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameController.text.trim().isEmpty
                                        ? l10n.translate('worker')
                                        : nameController.text.trim(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    phoneController.text.trim().isEmpty
                                        ? l10n.translate('no_phone')
                                        : phoneController.text.trim(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    publishedVehicles > 0
                                        ? l10n.translate('active')
                                        : l10n.translate('waiting_approval'),
                                    style: TextStyle(
                                      color: publishedVehicles > 0
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('my_vehicles'),
                              value: totalVehicles.toString(),
                              icon: Icons.directions_car_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('pending_review'),
                              value: pendingVehicles.toString(),
                              icon: Icons.hourglass_top_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('published'),
                              value: publishedVehicles.toString(),
                              icon: Icons.verified_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        l10n.translate('worker_and_scrapyard_data'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            _InputField(
                              controller: nameController,
                              label: l10n.translate('worker_name'),
                              hint: l10n.translate('worker_name_hint'),
                            ),
                            const SizedBox(height: 12),
                            _InputField(
                              controller: phoneController,
                              label: l10n.translate('phone'),
                              hint: '05xxxxxxxx',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            _InputField(
                              controller: scrapyardNameController,
                              label: l10n.translate('scrapyard_name'),
                              hint: l10n.translate('scrapyard_name_hint'),
                            ),
                            const SizedBox(height: 16),
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
                                    l10n.translate('current_actual_location'),
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
                                  if ((scrapyardGoogleMapsUrl ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      scrapyardGoogleMapsUrl!,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: isGettingLocation
                                          ? null
                                          : _useCurrentLocation,
                                      icon: isGettingLocation
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.my_location_outlined),
                                      label: Text(
                                        isGettingLocation
                                            ? l10n.translate('getting_location')
                                            : l10n.translate('use_current_location'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isSaving ? null : _saveWorkerProfile,
                                child: isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(l10n.translate('save')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        l10n.translate('settings'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          _ProfileTile(
                            icon: Icons.add_photo_alternate_outlined,
                            title: l10n.translate('add_new_vehicle'),
                            subtitle: l10n.translate('open_add_vehicle_and_upload'),
                            onTap: _openAddVehicle,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.verified_user_outlined,
                            title: l10n.translate('approval_status'),
                            subtitle: l10n.translate('track_vehicle_approval_status'),
                            onTap: () => _showApprovalStatusSheet(
                              totalVehicles: totalVehicles,
                              pendingVehicles: pendingVehicles,
                              publishedVehicles: publishedVehicles,
                              rejectedVehicles: rejectedVehicles,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: l10n.translate('notifications'),
                            subtitle: l10n.translate('view_latest_notifications_and_messages'),
                            onTap: _showNotificationsSheet,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            title: l10n.translate('open_scrapyard_location'),
                            subtitle: l10n.translate('open_saved_scrapyard_location'),
                            onTap: _openMapUrl,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.support_agent_outlined,
                            title: l10n.translate('support'),
                            subtitle: l10n.translate('quick_help_common_issues'),
                            onTap: _showSupportSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2B1D1D),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _signOut,
                          child: Text(l10n.translate('logout')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _StatusInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
            fontWeight: FontWeight.w900,
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
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }
}