import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../data/services/routes_service.dart';
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
  static const double _driverRouteRefreshMeters = 40;
  static const double _targetRouteRefreshMeters = 20;
  static const int _routeRefreshSeconds = 20;
  static const int _cameraRefreshMilliseconds = 1800;

  bool isOpeningChat = false;
  bool _followDriver = true;

  GoogleMapController? _mapController;

  LatLng? _lastTrackedLocation;
  DateTime? _lastUpdatedAt;

  RouteDetails? _route;
  bool _isLoadingRoute = false;

  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  DateTime? _lastRouteRequestedAt;

  Marker? _animatedTrackedMarker;
  LatLng? _animatedTrackedPosition;
  double _animatedRotation = 0;
  DateTime? _lastCameraMoveAt;

  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _workerMarkerIcon;

  String get _requestId => (widget.request['id'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _prepareMarkerIcons();
  }

  Future<void> _prepareMarkerIcons() async {
    _driverMarkerIcon = await _loadMarkerIcon(
      assetPath: 'assets/icons/driver_car_marker.png',
      fallbackHue: BitmapDescriptor.hueAzure,
    );

    _workerMarkerIcon = await _loadMarkerIcon(
      assetPath: 'assets/icons/worker_van_marker.png',
      fallbackHue: BitmapDescriptor.hueOrange,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<BitmapDescriptor> _loadMarkerIcon({
    required String assetPath,
    required double fallbackHue,
  }) async {
    try {
      return await BitmapDescriptor.asset(
        const ImageConfiguration(
          size: Size(56, 56),
          devicePixelRatio: 2.0,
        ),
        assetPath,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(fallbackHue);
    }
  }

  String _workerIdFromRequest(Map<String, dynamic> request) {
    return (request['workerId'] ??
            request['assignedWorkerId'] ??
            request['acceptedWorkerId'] ??
            '')
        .toString()
        .trim();
  }

  String _driverIdFromRequest(Map<String, dynamic> request) {
    return (request['assignedDriverId'] ?? request['driverId'] ?? '')
        .toString()
        .trim();
  }

  bool _canOpenChat(Map<String, dynamic> request) {
    final requestId = (request['id'] ?? '').toString().trim();
    final customerId = (request['customerId'] ?? '').toString().trim();
    final workerId = _workerIdFromRequest(request);
    final status = (request['status'] ?? '').toString().trim();

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

  double _degToRad(double degrees) => degrees * math.pi / 180.0;

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);

    final value = sinLat * sinLat +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            sinLng *
            sinLng;

    final c = 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
    return earthRadius * c;
  }

  double _normalizeRotation(double rotation) {
    var value = rotation % 360;
    if (value < 0) value += 360;
    return value;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lon1 = _degToRad(from.longitude);
    final lat2 = _degToRad(to.latitude);
    final lon2 = _degToRad(to.longitude);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return _normalizeRotation(bearing);
  }

  bool _shouldRefreshRoute(LatLng origin, LatLng destination) {
    final routeAgeSeconds = _lastRouteRequestedAt == null
        ? null
        : DateTime.now().difference(_lastRouteRequestedAt!).inSeconds;

    final originChanged = _lastRouteOrigin == null ||
        _distanceMeters(_lastRouteOrigin!, origin) >=
            _driverRouteRefreshMeters;

    final destinationChanged = _lastRouteDestination == null ||
        _distanceMeters(_lastRouteDestination!, destination) >=
            _targetRouteRefreshMeters;

    if (originChanged || destinationChanged) return true;
    if (routeAgeSeconds == null) return true;

    return routeAgeSeconds >= _routeRefreshSeconds;
  }

  void _scheduleRouteRefresh(LatLng origin, LatLng destination) {
    if (!_shouldRefreshRoute(origin, destination)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateRoute(origin, destination);
    });
  }

  Future<void> _updateRoute(LatLng origin, LatLng destination) async {
    if (_isLoadingRoute) return;

    _isLoadingRoute = true;
    _lastRouteOrigin = origin;
    _lastRouteDestination = destination;
    _lastRouteRequestedAt = DateTime.now();

    try {
      final route = await RoutesService.instance.computeRoute(
        origin: origin,
        destination: destination,
      );

      if (!mounted) return;

      setState(() {
        _route = route;
      });
    } catch (_) {
      // تجاهل فشل المسار حتى لا تنهار الشاشة
    } finally {
      _isLoadingRoute = false;
    }
  }

  Future<void> _openChat(Map<String, dynamic> request) async {
    final customerId = (request['customerId'] ?? '').toString().trim();
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> _requestStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(_requestId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _trackingLocationStream({
    required String trackingId,
    required bool isDriver,
  }) {
    if (isDriver) {
      return FirebaseFirestore.instance
          .collection('drivers')
          .doc(trackingId)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('workers')
        .doc(trackingId)
        .snapshots();
  }

  Future<void> _followTrackedPosition(
    LatLng position, {
    required double rotation,
  }) async {
    if (!_followDriver || _mapController == null) return;

    final now = DateTime.now();
    if (_lastCameraMoveAt != null &&
        now.difference(_lastCameraMoveAt!).inMilliseconds <
            _cameraRefreshMilliseconds) {
      return;
    }

    _lastCameraMoveAt = now;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 15.5,
            bearing: rotation,
            tilt: 45,
          ),
        ),
      );
    } catch (_) {}
  }

  void _syncAnimatedMarker({
    required LatLng livePosition,
    required bool isDriverTracking,
    required double? heading,
  }) {
    final previousPosition = _animatedTrackedPosition;
    _animatedTrackedPosition = livePosition;

    var rotation = _animatedRotation;

    if (heading != null && heading.isFinite && heading > 0) {
      rotation = _normalizeRotation(heading);
    } else if (previousPosition != null &&
        _distanceMeters(previousPosition, livePosition) >= 3) {
      rotation = _bearingBetween(previousPosition, livePosition);
    }

    _animatedRotation = rotation;
    _animatedTrackedMarker = Marker(
      markerId: const MarkerId('tracked'),
      position: livePosition,
      rotation: _animatedRotation,
      flat: true,
      anchor: const Offset(0.5, 0.56),
      icon: isDriverTracking
          ? (_driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ))
          : (_workerMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              )),
      infoWindow: InfoWindow(
        title: isDriverTracking ? 'السائق' : 'العامل',
      ),
    );
  }

  Widget _buildTrackingMap(Map<String, dynamic> request) {
    final driverId = _driverIdFromRequest(request);
    final workerId = _workerIdFromRequest(request);

    final trackingId = driverId.isNotEmpty ? driverId : workerId;
    final isDriverTracking = driverId.isNotEmpty;

    if (trackingId.isEmpty) {
      return const _MapPlaceholder(
        title: 'لا يمكن عرض التتبع الآن',
        subtitle: 'لم يتم ربط عامل أو سائق بهذا الطلب حتى الآن.',
        icon: Icons.location_off_outlined,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _trackingLocationStream(
        trackingId: trackingId,
        isDriver: isDriverTracking,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (data == null) {
          return _MapPlaceholder(
            title: 'بانتظار بدء التتبع',
            subtitle: isDriverTracking
                ? 'سيظهر موقع السائق هنا عند بدء التوصيل'
                : 'سيظهر موقع العامل هنا عند بدء الشحن',
            icon: Icons.hourglass_empty,
          );
        }

        final lat = _readDouble(data['lat']);
        final lng = _readDouble(data['lng']);
        final heading = _readDouble(data['heading']);

        if (lat == null || lng == null) {
          return _MapPlaceholder(
            title: 'الموقع غير متوفر',
            subtitle: isDriverTracking
                ? 'لم يبدأ السائق التتبع بعد'
                : 'لم يبدأ العامل التتبع بعد',
            icon: Icons.location_disabled,
          );
        }

        final trackedPosition = LatLng(lat, lng);
        final target = _requestTargetLatLng(request);

        _lastTrackedLocation = trackedPosition;

        final updatedAt = data['updatedAt'];
        if (updatedAt is Timestamp) {
          _lastUpdatedAt = updatedAt.toDate();
        }

        _syncAnimatedMarker(
          livePosition: trackedPosition,
          isDriverTracking: isDriverTracking,
          heading: heading,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _animatedTrackedPosition == null) return;

          _followTrackedPosition(
            _animatedTrackedPosition!,
            rotation: _animatedRotation,
          );
        });

        if (target != null) {
          _scheduleRouteRefresh(trackedPosition, target);
        }

        final markers = <Marker>{
          if (_animatedTrackedMarker != null) _animatedTrackedMarker!,
          if (target != null)
            Marker(
              markerId: const MarkerId('target'),
              position: target,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: 'موقع التوصيل'),
            ),
        };

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
                    target: trackedPosition,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMoveStarted: () {
                    if (_followDriver) {
                      setState(() => _followDriver = false);
                    }
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  if (_route != null)
                    Container(
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _followDriver ? Colors.green : Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _followDriver ? 'متابعة تلقائية' : 'متابعة متوقفة',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
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
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'toggle_follow_btn',
                    onPressed: () {
                      setState(() => _followDriver = !_followDriver);

                      final trackedLocation = _lastTrackedLocation;
                      if (_followDriver && trackedLocation != null) {
                        _followTrackedPosition(
                          trackedLocation,
                          rotation: _animatedRotation,
                        );
                      }
                    },
                    child: Icon(
                      _followDriver ? Icons.gps_fixed : Icons.gps_not_fixed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'center_driver_btn',
                    onPressed: () {
                      final trackedLocation = _lastTrackedLocation;
                      if (_mapController != null && trackedLocation != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(trackedLocation),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ],
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

        final status = (request['status'] ?? '').toString().trim();
        final scrapyardName =
            (request['scrapyardName'] ?? 'غير محدد').toString();
        final scrapyardLocation =
            (request['scrapyardLocation'] ??
                    request['scrapyardGoogleMapsUrl'] ??
                    '')
                .toString()
                .trim();

        final deliveryAddress =
            (request['deliveryAddress'] ?? '').toString().trim();
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
                                color:
                                    _statusColor(status).withValues(alpha: 0.16),
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
                              if (deliveryLat != null && deliveryLng != null) ...[
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
                                      ? 'الطلب في مرحلة الشحن. يمكنك متابعة موقع السائق أو العامل والتنسيق عبر المحادثة.'
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
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
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
