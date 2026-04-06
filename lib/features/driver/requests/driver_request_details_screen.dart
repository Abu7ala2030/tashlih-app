import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/routes_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';

class DriverRequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const DriverRequestDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  State<DriverRequestDetailsScreen> createState() =>
      _DriverRequestDetailsScreenState();
}

class _DriverRequestDetailsScreenState extends State<DriverRequestDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const int _cameraRefreshMilliseconds = 1800;
  static const int _markerAnimationMilliseconds = 900;
  static const double _cameraZoomFollow = 15.6;
  static const double _cameraTiltFollow = 40;
  static const double _cameraMoveThresholdMeters = 5;
  static const double _routeRefreshMeters = 30;
  static const int _routeRefreshSeconds = 20;

  static const double _pickupAutoArrivalMeters = 80;
  static const double _deliveryAutoArrivalMeters = 70;

  bool isSubmitting = false;
  bool _followDriver = true;
  bool _isSatelliteView = false;
  bool _autoPickupHandled = false;
  bool _autoDeliveryHandled = false;

  GoogleMapController? _mapController;

  BitmapDescriptor? _driverMarkerIcon;
  LatLng? _lastTrackedLocation;
  DateTime? _lastUpdatedAt;
  double? _lastSpeedKmh;
  double? _lastAccuracyMeters;
  DateTime? _lastCameraMoveAt;

  RouteDetails? _route;
  bool _isLoadingRoute = false;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  DateTime? _lastRouteRequestedAt;

  Marker? _animatedTrackedMarker;
  LatLng? _animatedTrackedPosition;
  double _animatedRotation = 0;

  late final AnimationController _markerAnimationController;
  LatLng? _animationStartPosition;
  LatLng? _animationEndPosition;
  double _animationStartRotation = 0;
  double _animationEndRotation = 0;

  String get _requestId => (widget.request['id'] ?? '').toString().trim();

  String get _currentDriverId => context.read<AuthProvider>().uid?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _markerAnimationMilliseconds),
    )..addListener(_onMarkerAnimationTick);

    _prepareMarkerIcon();
  }

  @override
  void dispose() {
    _markerAnimationController
      ..removeListener(_onMarkerAnimationTick)
      ..dispose();
    super.dispose();
  }

  Future<void> _prepareMarkerIcon() async {
    try {
      _driverMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(
          size: Size(56, 56),
          devicePixelRatio: 2.0,
        ),
        'assets/icons/driver_car_marker.png',
      );
    } catch (_) {
      _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onMarkerAnimationTick() {
    final start = _animationStartPosition;
    final end = _animationEndPosition;
    if (start == null || end == null) return;

    final t = Curves.easeOutCubic.transform(_markerAnimationController.value);

    final lat = ui.lerpDouble(start.latitude, end.latitude, t) ?? end.latitude;
    final lng = ui.lerpDouble(start.longitude, end.longitude, t) ?? end.longitude;
    final rotation = _lerpRotation(
      _animationStartRotation,
      _animationEndRotation,
      t,
    );

    final interpolated = LatLng(lat, lng);

    _animatedTrackedPosition = interpolated;
    _animatedRotation = rotation;
    _animatedTrackedMarker = _buildDriverMarker(
      position: interpolated,
      rotation: rotation,
    );

    if (mounted) {
      setState(() {});
    }

    _followTrackedPosition(
      interpolated,
      rotation: rotation,
      force: false,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _requestStream() {
    return FirebaseFirestore.instance
        .collection('requests')
        .doc(_requestId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _driverStream() {
    return FirebaseFirestore.instance
        .collection('drivers')
        .doc(_currentDriverId)
        .snapshots();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _customerLatLng(Map<String, dynamic> request) {
    final lat = _toDouble(request['deliveryLat']);
    final lng = _toDouble(request['deliveryLng']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _pickupLatLng(Map<String, dynamic> request) {
    final lat = _toDouble(
      request['pickupLat'] ?? request['scrapyardLat'] ?? request['workerLat'],
    );
    final lng = _toDouble(
      request['pickupLng'] ?? request['scrapyardLng'] ?? request['workerLng'],
    );
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _activeTarget(Map<String, dynamic> request) {
    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    if (deliveryStatus == 'awaiting_driver_assignment' ||
        deliveryStatus == 'pending_pickup') {
      return _pickupLatLng(request) ?? _customerLatLng(request);
    }
    return _customerLatLng(request);
  }

  String _activeTargetTitle(Map<String, dynamic> request) {
    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    if (deliveryStatus == 'awaiting_driver_assignment' ||
        deliveryStatus == 'pending_pickup') {
      return 'نقطة الاستلام';
    }
    return 'العميل';
  }

  Future<void> _callCustomer(Map<String, dynamic> request) async {
    final phone = (request['phone'] ?? request['customerPhone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم العميل غير متوفر')),
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

  Future<void> _openNavigationToActiveTarget(Map<String, dynamic> request) async {
    final target = _activeTarget(request);
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإحداثيات غير متوفرة')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الملاحة')),
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String success,
    Future<void> Function()? beforeSuccess,
    Future<void> Function()? afterSuccess,
    bool popAfter = false,
  }) async {
    if (_requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      if (beforeSuccess != null) {
        await beforeSuccess();
      }
      await action();
      if (afterSuccess != null) {
        await afterSuccess();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      if (popAfter) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  String _deliveryStatusText(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return 'بانتظار بدء التنفيذ';
      case 'pending_pickup':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      default:
        if (status == 'assigned') return 'تم إسناد الطلب';
        if (status == 'shipped') return 'قيد التوصيل';
        if (status == 'delivered') return 'تم التسليم';
        return 'قيد المعالجة';
    }
  }

  String _driverHelpText(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
      case 'pending_pickup':
        return 'توجّه الآن إلى نقطة الاستلام. عند الوصول يمكنك تأكيد الاستلام يدويًا أو سيتم رصد الوصول تلقائيًا إذا كنت قريبًا جدًا.';
      case 'picked_up':
        return 'تم الاستلام بنجاح. ابدأ الآن التوصيل للعميل لتفعيل التتبع الحي في وضع التسليم.';
      case 'on_the_way':
        return 'أنت الآن في مرحلة التوصيل. راقب ETA والمسافة، ويمكن تأكيد التسليم يدويًا أو تلقائيًا عند الاقتراب.';
      case 'delivered':
        return 'هذا الطلب اكتمل بنجاح.';
      default:
        if (status == 'assigned') {
          return 'الطلب جاهز لبدء التحرك إلى نقطة الاستلام.';
        }
        return 'تابع الرحلة من هذه الشاشة.';
    }
  }

  Color _statusColor(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
      case 'pending_pickup':
        return Colors.orange;
      case 'picked_up':
        return Colors.teal;
      case 'on_the_way':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        if (status == 'delivered') return Colors.green;
        if (status == 'assigned' || status == 'shipped') return Colors.orange;
        return Colors.grey;
    }
  }

  int _tripStageIndex(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return 0;
      case 'pending_pickup':
        return 1;
      case 'picked_up':
        return 2;
      case 'on_the_way':
        return 3;
      case 'delivered':
        return 4;
      default:
        if (status == 'assigned') return 1;
        if (status == 'shipped') return 3;
        if (status == 'delivered') return 4;
        return 0;
    }
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

  double _lerpRotation(double start, double end, double t) {
    final normalizedStart = _normalizeRotation(start);
    final normalizedEnd = _normalizeRotation(end);
    var delta = normalizedEnd - normalizedStart;

    if (delta.abs() > 180) {
      delta = delta > 0 ? delta - 360 : delta + 360;
    }

    return _normalizeRotation(normalizedStart + (delta * t));
  }

  bool _shouldRefreshRoute(LatLng origin, LatLng destination) {
    final routeAgeSeconds = _lastRouteRequestedAt == null
        ? null
        : DateTime.now().difference(_lastRouteRequestedAt!).inSeconds;

    final originChanged = _lastRouteOrigin == null ||
        _distanceMeters(_lastRouteOrigin!, origin) >= _routeRefreshMeters;

    final destinationChanged = _lastRouteDestination == null ||
        _distanceMeters(_lastRouteDestination!, destination) >= _routeRefreshMeters;

    if (originChanged || destinationChanged) return true;
    if (routeAgeSeconds == null) return true;

    return routeAgeSeconds >= _routeRefreshSeconds;
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
      // ignore
    } finally {
      _isLoadingRoute = false;
    }
  }

  Future<void> _fitDriverAndTarget(Map<String, dynamic> request) async {
    final controller = _mapController;
    final driver = _animatedTrackedPosition;
    final target = _activeTarget(request);

    if (controller == null || driver == null || target == null) return;

    final south = math.min(driver.latitude, target.latitude);
    final north = math.max(driver.latitude, target.latitude);
    final west = math.min(driver.longitude, target.longitude);
    final east = math.max(driver.longitude, target.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } catch (_) {}
  }

  Future<void> _followTrackedPosition(
    LatLng position, {
    required double rotation,
    bool force = false,
  }) async {
    if (!_followDriver || _mapController == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastCameraMoveAt != null &&
        now.difference(_lastCameraMoveAt!).inMilliseconds <
            _cameraRefreshMilliseconds) {
      return;
    }

    if (!force &&
        _lastTrackedLocation != null &&
        _distanceMeters(_lastTrackedLocation!, position) < _cameraMoveThresholdMeters) {
      return;
    }

    _lastCameraMoveAt = now;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: _cameraZoomFollow,
            tilt: _cameraTiltFollow,
            bearing: rotation,
          ),
        ),
      );
    } catch (_) {}
  }

  Marker _buildDriverMarker({
    required LatLng position,
    required double rotation,
  }) {
    return Marker(
      markerId: const MarkerId('driver_marker'),
      position: position,
      rotation: rotation,
      flat: true,
      anchor: const Offset(0.5, 0.56),
      icon: _driverMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'موقعك الحالي'),
    );
  }

  void _animateDriverMarker({
    required LatLng livePosition,
    required double? heading,
  }) {
    final previousPosition = _animatedTrackedPosition;
    var targetRotation = _animatedRotation;

    if (heading != null && heading.isFinite && heading > 0) {
      targetRotation = _normalizeRotation(heading);
    } else if (previousPosition != null &&
        _distanceMeters(previousPosition, livePosition) >= 2) {
      targetRotation = _bearingBetween(previousPosition, livePosition);
    }

    if (previousPosition == null) {
      _animatedTrackedPosition = livePosition;
      _animatedRotation = targetRotation;
      _animatedTrackedMarker = _buildDriverMarker(
        position: livePosition,
        rotation: targetRotation,
      );
      return;
    }

    final movement = _distanceMeters(previousPosition, livePosition);
    if (movement < 1.5) {
      _animatedTrackedPosition = livePosition;
      _animatedRotation = targetRotation;
      _animatedTrackedMarker = _buildDriverMarker(
        position: livePosition,
        rotation: targetRotation,
      );
      return;
    }

    _animationStartPosition = previousPosition;
    _animationEndPosition = livePosition;
    _animationStartRotation = _animatedRotation;
    _animationEndRotation = targetRotation;

    _markerAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  Future<void> _autoHandleArrival(Map<String, dynamic> request) async {
    final driver = _animatedTrackedPosition;
    if (driver == null || isSubmitting) return;

    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    final provider = context.read<RequestProvider>();

    if ((deliveryStatus == 'awaiting_driver_assignment' ||
            deliveryStatus == 'pending_pickup') &&
        !_autoPickupHandled) {
      final pickup = _pickupLatLng(request);
      if (pickup != null &&
          _distanceMeters(driver, pickup) <= _pickupAutoArrivalMeters) {
        _autoPickupHandled = true;
        await provider.markDriverPickedUp(requestId: _requestId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رصد الوصول لنقطة الاستلام تلقائيًا')),
        );
        return;
      }
    }

    if ((deliveryStatus == 'on_the_way' ||
            (request['status'] ?? '').toString().trim() == 'shipped') &&
        !_autoDeliveryHandled) {
      final customer = _customerLatLng(request);
      if (customer != null &&
          _distanceMeters(driver, customer) <= _deliveryAutoArrivalMeters) {
        _autoDeliveryHandled = true;
        await provider.markDriverDelivered(requestId: _requestId);
        LocationService.instance.stopTracking();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رصد الوصول للعميل تلقائيًا')),
        );
      }
    }
  }

  Widget _buildDriverMap(Map<String, dynamic> request) {
    final target = _activeTarget(request);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        if (snapshot.connectionState == ConnectionState.waiting &&
            _animatedTrackedMarker == null) {
          return const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final lat = _toDouble(data?['lat']);
        final lng = _toDouble(data?['lng']);
        final heading = _toDouble(data?['heading']);
        final speedMps = _toDouble(data?['speed']);
        final accuracy = _toDouble(data?['accuracy']);

        if ((lat == null || lng == null) && _animatedTrackedMarker == null) {
          return const _MapPlaceholder(
            title: 'لم يبدأ التتبع بعد',
            subtitle: 'ابدأ التوصيل أو فعّل الموقع ليظهر مسارك هنا.',
            icon: Icons.location_disabled,
          );
        }

        if (lat != null && lng != null) {
          final livePosition = LatLng(lat, lng);

          _lastTrackedLocation = livePosition;
          _lastSpeedKmh = speedMps == null ? null : speedMps * 3.6;
          _lastAccuracyMeters = accuracy;

          final updatedAt = data?['updatedAt'];
          if (updatedAt is Timestamp) {
            _lastUpdatedAt = updatedAt.toDate();
          }

          _animateDriverMarker(
            livePosition: livePosition,
            heading: heading,
          );

          if (target != null && _shouldRefreshRoute(livePosition, target)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _updateRoute(livePosition, target);
            });
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _autoHandleArrival(request);
          });
        }

        final activeTarget = _activeTarget(request);

        final initialTarget = _animatedTrackedPosition ??
            activeTarget ??
            const LatLng(26.4207, 50.0888);

        final markers = <Marker>{
          if (_animatedTrackedMarker != null) _animatedTrackedMarker!,
          if (activeTarget != null)
            Marker(
              markerId: const MarkerId('active_target'),
              position: activeTarget,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(title: _activeTargetTitle(request)),
            ),
        };

        final polylines = _route == null
            ? <Polyline>{}
            : {
                Polyline(
                  polylineId: const PolylineId('driver_route'),
                  points: _route!.polylinePoints,
                  width: 5,
                ),
              };

        return Stack(
          children: [
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 14,
                  ),
                  mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  trafficEnabled: true,
                  buildingsEnabled: true,
                  compassEnabled: false,
                  markers: markers,
                  polylines: polylines,
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
                          Text('ETA: ${_route!.etaLabel}'),
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
              left: 10,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MapInfoChip(
                    icon: Icons.speed_outlined,
                    text: _formatSpeed(_lastSpeedKmh),
                  ),
                  _MapInfoChip(
                    icon: Icons.gps_fixed,
                    text: _formatAccuracy(_lastAccuracyMeters),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'driver_follow_toggle',
                    onPressed: () {
                      setState(() => _followDriver = !_followDriver);
                      final tracked = _animatedTrackedPosition;
                      if (_followDriver && tracked != null) {
                        _followTrackedPosition(
                          tracked,
                          rotation: _animatedRotation,
                          force: true,
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
                    heroTag: 'driver_center_btn',
                    onPressed: () {
                      final tracked = _animatedTrackedPosition;
                      if (_mapController != null && tracked != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(tracked),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'driver_fit_btn',
                    onPressed: () => _fitDriverAndTarget(request),
                    child: const Icon(Icons.fit_screen_outlined),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'driver_map_type_btn',
                    onPressed: () {
                      setState(() => _isSatelliteView = !_isSatelliteView);
                    },
                    child: Icon(
                      _isSatelliteView
                          ? Icons.layers_clear_outlined
                          : Icons.layers_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    return '${diff.inHours} ساعة';
  }

  String _formatSpeed(double? speedKmh) {
    if (speedKmh == null || !speedKmh.isFinite || speedKmh <= 0) {
      return '0 كم/س';
    }
    return '${speedKmh.toStringAsFixed(0)} كم/س';
  }

  String _formatAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null || !accuracyMeters.isFinite || accuracyMeters <= 0) {
      return 'غير معروف';
    }
    if (accuracyMeters < 10) return '${accuracyMeters.toStringAsFixed(0)} م';
    return '${accuracyMeters.toStringAsFixed(0)} متر';
  }

  Widget _buildTripProgress(String deliveryStatus, String status) {
    const stages = [
      'تعيين السائق',
      'الاستلام',
      'التجهيز',
      'في الطريق',
      'التسليم',
    ];
    final currentIndex = _tripStageIndex(deliveryStatus, status);

    return Column(
      children: [
        Row(
          children: List.generate(stages.length, (index) {
            final active = index <= currentIndex;
            return Expanded(
              child: Container(
                margin: EdgeInsetsDirectional.only(
                  end: index == stages.length - 1 ? 0 : 6,
                ),
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.green : Colors.white12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          stages[currentIndex.clamp(0, stages.length - 1)],
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_requestId.isEmpty) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(child: Text('تعذر تحميل الطلب')),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        final request = {
          ...widget.request,
          ...?snapshot.data?.data(),
          'id': _requestId,
        };

        final partName = (request['partName'] ?? '').toString().trim();
        final vehicle =
            '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}'
                .trim();
        final deliveryAddress =
            (request['deliveryAddress'] ?? '').toString().trim();
        final customerPhone = (request['phone'] ?? '').toString().trim();
        final scrapyardName = (request['scrapyardName'] ?? '').toString().trim();
        final notes = (request['notes'] ?? '').toString().trim();
        final status = (request['status'] ?? '').toString().trim();
        final deliveryStatus =
            (request['deliveryStatus'] ?? '').toString().trim();

        final statusText = _deliveryStatusText(deliveryStatus, status);
        final statusColor = _statusColor(deliveryStatus, status);
        final activeTargetTitle = _activeTargetTitle(request);

        if (deliveryStatus == 'delivered' || status == 'delivered') {
          _autoDeliveryHandled = true;
        }
        if (deliveryStatus == 'picked_up' ||
            deliveryStatus == 'on_the_way' ||
            deliveryStatus == 'delivered' ||
            status == 'shipped' ||
            status == 'delivered') {
          _autoPickupHandled = true;
        }

        return Stack(
          children: [
            Scaffold(
              body: AppGradientBackground(
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'تفاصيل طلب السائق',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                partName.isEmpty ? 'طلب بدون اسم' : partName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'حالة الرحلة',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTripProgress(deliveryStatus, status),
                            const SizedBox(height: 12),
                            Text(
                              _driverHelpText(deliveryStatus, status),
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'الخريطة المباشرة',
                        child: _buildDriverMap(request),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'معلومات الطلب',
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'المركبة',
                              value: vehicle.isEmpty ? '-' : vehicle,
                            ),
                            _DetailRow(
                              label: activeTargetTitle,
                              value: activeTargetTitle == 'نقطة الاستلام'
                                  ? ((request['pickupAddress'] ??
                                                  request['scrapyardLocation'] ??
                                                  request['scrapyardName'] ??
                                                  '')
                                              .toString()
                                              .trim()
                                              .isEmpty
                                          ? 'غير محدد'
                                          : (request['pickupAddress'] ??
                                                  request['scrapyardLocation'] ??
                                                  request['scrapyardName'] ??
                                                  '')
                                              .toString()
                                              .trim())
                                  : (deliveryAddress.isEmpty
                                      ? 'غير محدد'
                                      : deliveryAddress),
                            ),
                            _DetailRow(
                              label: 'هاتف العميل',
                              value: customerPhone.isEmpty
                                  ? 'غير متوفر'
                                  : customerPhone,
                            ),
                            _DetailRow(
                              label: 'التشليح',
                              value: scrapyardName.isEmpty
                                  ? 'غير محدد'
                                  : scrapyardName,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'ملاحظات',
                        child: Text(
                          notes.isEmpty ? 'لا توجد ملاحظات' : notes,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'إجراءات السائق',
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _callCustomer(request),
                                icon: const Icon(Icons.phone_outlined),
                                label: const Text('اتصال بالعميل'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openNavigationToActiveTarget(request),
                                icon: const Icon(Icons.navigation_outlined),
                                label: Text('فتح الملاحة إلى $activeTargetTitle'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (deliveryStatus == 'awaiting_driver_assignment' ||
                                deliveryStatus == 'pending_pickup')
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => _runAction(
                                            action: () => context
                                                .read<RequestProvider>()
                                                .markDriverPickedUp(
                                                  requestId: _requestId,
                                                ),
                                            success: 'تم تأكيد استلام الطلب',
                                          ),
                                  icon: const Icon(Icons.inventory_2_outlined),
                                  label: const Text(
                                    'تأكيد الاستلام من العامل/التشليح',
                                  ),
                                ),
                              ),
                            if (deliveryStatus == 'picked_up')
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => _runAction(
                                            beforeSuccess: () async {
                                              final driverId = _currentDriverId;
                                              if (driverId.isNotEmpty) {
                                                await FirebaseFirestore.instance
                                                    .collection('drivers')
                                                    .doc(driverId)
                                                    .set({
                                                  'isOnline': true,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                }, SetOptions(merge: true));
                                              }
                                            },
                                            action: () => context
                                                .read<RequestProvider>()
                                                .markDriverOnTheWay(
                                                  requestId: _requestId,
                                                ),
                                            afterSuccess: () async {
                                              final driverId = _currentDriverId;
                                              if (driverId.isNotEmpty) {
                                                await LocationService.instance
                                                    .startTracking(
                                                  driverId: driverId,
                                                );
                                              }
                                            },
                                            success:
                                                'تم تحديث الحالة إلى في الطريق وبدأ التتبع المباشر',
                                          ),
                                  icon: const Icon(Icons.route_outlined),
                                  label: const Text('بدأت التوصيل للعميل'),
                                ),
                              ),
                            if (deliveryStatus == 'on_the_way' ||
                                status == 'shipped')
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => _runAction(
                                            action: () => context
                                                .read<RequestProvider>()
                                                .markDriverDelivered(
                                                  requestId: _requestId,
                                                ),
                                            afterSuccess: () async {
                                              LocationService.instance
                                                  .stopTracking();
                                            },
                                            success: 'تم تأكيد التسليم',
                                          ),
                                  icon: const Icon(Icons.verified_outlined),
                                  label: const Text('تأكيد التسليم للعميل'),
                                ),
                              ),
                            if (deliveryStatus == 'delivered' ||
                                status == 'delivered')
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'هذا الطلب مكتمل وتم تسليمه.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
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
            if (isSubmitting)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class _MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MapInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
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
      height: 280,
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
