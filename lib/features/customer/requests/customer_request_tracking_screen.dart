import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../data/services/routes_service.dart';
import '../../chat/chat_screen.dart';

LatLng? _lastRouteWorker;
LatLng? _lastRouteTarget;

class CustomerRequestTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CustomerRequestTrackingScreen({super.key, required this.request});

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

  RouteDetails? _route;
  bool _isLoadingRoute = false;

  String get _requestId => (widget.request['id'] ?? '').toString();

  String _workerIdFromRequest(Map<String, dynamic> request) {
    return (request['workerId'] ??
            request['assignedWorkerId'] ??
            request['acceptedWorkerId'] ??
            '')
        .toString();
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

  LatLng? _requestTargetLatLng(Map<String, dynamic> request) {
    final lat = _readDouble(
      request['deliveryLat'] ?? request['targetLat'] ?? request['lat'],
    );
    final lng = _readDouble(
      request['deliveryLng'] ?? request['targetLng'] ?? request['lng'],
    );

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    return '${diff.inHours} ساعة';
  }

  Future<void> _updateRoute(LatLng worker, LatLng target) async {
    if (_isLoadingRoute) return;

    setState(() => _isLoadingRoute = true);

    try {
      final route = await RoutesService.instance.computeRoute(
        origin: worker,
        destination: target,
      );

      if (!mounted) return;
      setState(() => _route = route);
    } catch (e) {
      debugPrint('Route error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Future<void> _openChat(Map<String, dynamic> request) async {
    final customerId = (request['customerId'] ?? '').toString();
    final workerId = _workerIdFromRequest(request);

    if (!_canOpenChat(request) || isOpeningChat) return;

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
          builder: (_) => ChatScreen(chatId: chatId, title: 'محادثة العامل'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل فتح المحادثة: $e')));
    } finally {
      if (mounted) {
        setState(() => isOpeningChat = false);
      }
    }
  }

  Future<void> _callWorker(Map<String, dynamic> request) async {
    final phone = (request['workerPhone'] ?? request['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رقم العامل غير متوفر')));
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تعذر إجراء الاتصال')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تعذر فتح الموقع')));
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
        final data = snapshot.data?.data();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (data == null) {
          return const _MapPlaceholder(
            title: 'بانتظار بدء التتبع',
            subtitle: 'سيظهر موقع العامل هنا عند بدء الشحن',
            icon: Icons.hourglass_empty,
          );
        }

        final lat = _readDouble(data['lat']);
        final lng = _readDouble(data['lng']);

        if (lat == null || lng == null) {
          return const _MapPlaceholder(
            title: 'الموقع غير متوفر',
            subtitle: 'لم يبدأ العامل التتبع بعد',
            icon: Icons.location_disabled,
          );
        }

        final worker = LatLng(lat, lng);
        final target = _requestTargetLatLng(request);

        _lastWorkerLocation = worker;

        final updatedAt = data['updatedAt'];
        if (updatedAt is Timestamp) {
          _lastUpdatedAt = updatedAt.toDate();
        }

        if (target != null) {
          final shouldRefreshRoute =
              _lastRouteWorker == null ||
              _lastRouteTarget == null ||
              _lastRouteWorker!.latitude != worker.latitude ||
              _lastRouteWorker!.longitude != worker.longitude ||
              _lastRouteTarget!.latitude != target.latitude ||
              _lastRouteTarget!.longitude != target.longitude;

          if (shouldRefreshRoute) {
            _lastRouteWorker = worker;
            _lastRouteTarget = target;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateRoute(worker, target);
            });
          }
        }

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('worker'),
            position: worker,
            infoWindow: const InfoWindow(title: 'العامل'),
          ),
        };

        if (target != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('target'),
              position: target,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: 'موقع التوصيل'),
            ),
          );
        }

        final polylines = _route == null
            ? <Polyline>{}
            : {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _route!.polylinePoints,
                  width: 5,
                ),
              };

        return Stack(
          children: [
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: worker,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (c) => _mapController = c,
                ),
              ),
            ),
            if (_route != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الوقت: ${_route!.etaLabel}'),
                      Text('المسافة: ${_route!.distanceLabel}'),
                    ],
                  ),
                ),
              ),
            if (_lastUpdatedAt != null)
              Positioned(
                top: 10,
                right: 10,
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
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_mapController != null && _lastWorkerLocation != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLng(_lastWorkerLocation!),
                    );
                  }
                },
                child: const Icon(Icons.my_location),
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
          child: SafeArea(child: Center(child: Text('تعذر تحميل الطلب'))),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        final request = {...widget.request, ...?liveData, 'id': _requestId};

        final status = (request['status'] ?? '').toString();
        final scrapyardName = (request['scrapyardName'] ?? 'غير محدد')
            .toString();
        final scrapyardLocation =
            (request['scrapyardLocation'] ??
                    request['scrapyardGoogleMapsUrl'] ??
                    '')
                .toString()
                .trim();

        final deliveryAddress = (request['deliveryAddress'] ?? '')
            .toString()
            .trim();
        final deliveryLat = _readDouble(request['deliveryLat']);
        final deliveryLng = _readDouble(request['deliveryLng']);

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
                                  onPressed: () =>
                                      _openMapUrl(scrapyardLocation),
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
                  if (deliveryAddress.isNotEmpty ||
                      (deliveryLat != null && deliveryLng != null))
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
                                'عنوان التوصيل',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (deliveryAddress.isNotEmpty)
                                Text(
                                  deliveryAddress,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                              if (deliveryLat != null &&
                                  deliveryLng != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'الإحداثيات: ${deliveryLat.toStringAsFixed(6)}, ${deliveryLng.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
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
                                onPressed:
                                    (_canOpenChat(request) && !isOpeningChat)
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
                                  _canOpenChat(request)
                                      ? 'محادثة العامل'
                                      : 'المحادثة متاحة بعد قبول العرض',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _canOpenChat(request)
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
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(.08))),
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
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
