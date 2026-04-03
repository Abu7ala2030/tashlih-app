import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/firestore_paths.dart';
import '../../chat/chat_screen.dart';

class CustomerRequestTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CustomerRequestTrackingScreen({
    super.key,
    required this.request,
  });

  @override
  State<CustomerRequestTrackingScreen> createState() =>
      _CustomerRequestTrackingScreenState();
}

class _CustomerRequestTrackingScreenState
    extends State<CustomerRequestTrackingScreen> {
  bool isOpeningChat = false;
  GoogleMapController? _mapController;

  LatLng? _lastWorkerLocation;
  DateTime? _lastUpdatedAt;

  String get _requestId => (widget.request['id'] ?? '').toString();

  Future<void> _openChat(Map<String, dynamic> request) async {
    final customerId = (request['customerId'] ?? '').toString();
    final workerId = _workerIdFromRequest(request);

    final canOpenChat = _canOpenChat(request);

    if (!canOpenChat || isOpeningChat) return;

    setState(() => isOpeningChat = true);

    try {
      final chatId = await ChatService.instance.createOrGetChat(
        requestId: _requestId,
        customerId: customerId,
        workerId: workerId,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: 'محادثة العامل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل فتح المحادثة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isOpeningChat = false);
      }
    }
  }

  String _workerIdFromRequest(Map<String, dynamic> request) {
    final direct = (request['workerId'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final assigned = (request['assignedWorkerId'] ?? '').toString().trim();
    if (assigned.isNotEmpty) return assigned;

    final accepted = (request['acceptedWorkerId'] ?? '').toString().trim();
    return accepted;
  }

  bool _canOpenChat(Map<String, dynamic> request) {
    final requestId = (request['id'] ?? '').toString();
    final customerId = (request['customerId'] ?? '').toString();
    final workerId = _workerIdFromRequest(request);
    final status = (request['status'] ?? '').toString();

    return requestId.isNotEmpty &&
        customerId.isNotEmpty &&
        workerId.isNotEmpty &&
        (status == 'assigned' || status == 'shipped' || status == 'delivered');
  }

  Future<void> _openMapUrl(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الموقع')),
    );
  }

  Future<void> _callWorker(Map<String, dynamic> request) async {
    final phone = (request['workerPhone'] ?? request['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم العامل غير متوفر')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر إجراء الاتصال')),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'assigned':
        return 'تم اختيار العرض';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'قيد المعالجة';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.teal;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priceText(Map<String, dynamic> request) {
    final raw = request['acceptedOfferPrice'] ?? '-';
    return '$raw ريال';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _requestStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(_requestId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _workerLocationStream(
    String workerId,
  ) {
    return FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .snapshots();
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed;
  }

  LatLng? _requestTargetLatLng(Map<String, dynamic> request) {
    final lat = _readDouble(
      request['deliveryLat'] ??
          request['targetLat'] ??
          request['destinationLat'] ??
          request['lat'],
    );
    final lng = _readDouble(
      request['deliveryLng'] ??
          request['targetLng'] ??
          request['destinationLng'] ??
          request['lng'],
    );

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    return '${diff.inHours} ساعة';
  }

  Widget _buildTrackingMap(Map<String, dynamic> request) {
    final workerId = _workerIdFromRequest(request);

    if (workerId.isEmpty) {
      return const _MapPlaceholder(
        title: 'لا يمكن عرض التتبع الآن',
        subtitle: 'لم يتم ربط عامل بهذا الطلب حتى الآن.',
        icon: Icons.location_off_outlined,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _workerLocationStream(workerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();

        if (data == null) {
          return const _MapPlaceholder(
            title: 'بانتظار بدء التتبع',
            subtitle: 'سيظهر موقع العامل هنا عند بدء الشحن',
            icon: Icons.hourglass_empty,
          );
        }

        final workerLat = _readDouble(data['lat']);
        final workerLng = _readDouble(data['lng']);
        final updatedAt = data['updatedAt'];

        if (updatedAt is Timestamp) {
          _lastUpdatedAt = updatedAt.toDate();
        }

        if (workerLat == null || workerLng == null) {
          return const _MapPlaceholder(
            title: 'موقع العامل غير متوفر',
            subtitle: 'لم يبدأ العامل التتبع بعد',
            icon: Icons.location_disabled,
          );
        }

        final workerLatLng = LatLng(workerLat, workerLng);
        _lastWorkerLocation = workerLatLng;

        final targetLatLng = _requestTargetLatLng(request);

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('worker'),
            position: workerLatLng,
            infoWindow: const InfoWindow(title: 'العامل'),
          ),
        };

        if (targetLatLng != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('target'),
              position: targetLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: 'موقع التسليم'),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(workerLatLng),
            );
          }
        });

        return Stack(
          children: [
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: workerLatLng,
                    zoom: 14,
                  ),
                  markers: markers,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black87,
                onPressed: () {
                  if (_lastWorkerLocation != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLng(_lastWorkerLocation!),
                    );
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ),
            if (_lastUpdatedAt != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'آخر تحديث: ${_formatTime(_lastUpdatedAt!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_requestId.isEmpty) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: Text('تعذر تحميل الطلب'),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        final request = {
          ...widget.request,
          ...?liveData,
          'id': _requestId,
        };

        final status = (request['status'] ?? '').toString();
        final scrapyardName =
            (request['scrapyardName'] ?? 'غير محدد').toString();
        final scrapyardLocation =
            (request['scrapyardLocation'] ?? '').toString().trim();

        final canOpenChat = _canOpenChat(request);

        return Scaffold(
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
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تتبع الطلب',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${request['partName'] ?? ''} • ${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.4,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الحالة الحالية',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _statusText(status),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusText(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الخريطة المباشرة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTrackingMap(request),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'القطعة المطلوبة',
                              value: (request['partName'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: 'المركبة',
                              value:
                                  '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                            ),
                            _InfoRow(
                              label: 'السعر المختار',
                              value: _priceText(request),
                            ),
                            _InfoRow(
                              label: 'المدينة',
                              value: (request['city'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: 'التشليح',
                              value: scrapyardName,
                              isLast: true,
                            ),
                            if (scrapyardLocation.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openMapUrl(scrapyardLocation),
                                  icon: const Icon(Icons.location_on_outlined),
                                  label: const Text('فتح موقع التشليح'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجراءات الطلب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              status == 'assigned'
                                  ? 'تم اعتماد العرض وبدأت مرحلة التنفيذ. يمكنك الآن التواصل مع العامل مباشرة.'
                                  : status == 'shipped'
                                      ? 'الطلب في مرحلة الشحن. يمكنك متابعة موقع العامل والتنسيق معه عبر المحادثة.'
                                      : status == 'delivered'
                                          ? 'تم التسليم. ما زال بإمكانك الرجوع للمحادثة عند الحاجة.'
                                          : 'سيظهر زر المحادثة بعد اعتماد أحد العروض.',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (canOpenChat && !isOpeningChat)
                                    ? () => _openChat(request)
                                    : null,
                                icon: isOpeningChat
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chat_bubble_outline),
                                label: Text(
                                  canOpenChat
                                      ? 'محادثة العامل'
                                      : 'المحادثة متاحة بعد قبول العرض',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: canOpenChat
                                    ? () => _callWorker(request)
                                    : null,
                                icon: const Icon(Icons.phone_outlined),
                                label: const Text('اتصال بالعامل'),
                              ),
                            ),
                          ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _MapPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: Colors.white70),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}