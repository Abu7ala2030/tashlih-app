import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
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
    extends State<CustomerRequestTrackingScreen>
    with SingleTickerProviderStateMixin {
  static const double _driverRouteRefreshMeters = 40;
  static const double _targetRouteRefreshMeters = 20;
  static const int _routeRefreshSeconds = 20;
  static const int _cameraRefreshMilliseconds = 1800;
  static const int _markerAnimationMilliseconds = 900;
  static const double _cameraZoomFollow = 15.4;
  static const double _cameraTiltFollow = 38;
  static const double _cameraMoveThresholdMeters = 5;

  bool isOpeningChat = false;
  bool _followDriver = true;
  bool _isSatelliteView = false;

  GoogleMapController? _mapController;

  LatLng? _lastTrackedLocation;
  DateTime? _lastUpdatedAt;
  double? _lastSpeedKmh;
  double? _lastAccuracyMeters;

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

  late final AnimationController _markerAnimationController;
  LatLng? _animationStartPosition;
  LatLng? _animationEndPosition;
  double _animationStartRotation = 0;
  double _animationEndRotation = 0;
  bool _animationIsDriverTracking = true;

  String get _requestId => (widget.request['id'] ?? '').toString().trim();
  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _markerAnimationMilliseconds),
    )..addListener(_onMarkerAnimationTick);

    _prepareMarkerIcons();
  }

  @override
  void dispose() {
    _markerAnimationController
      ..removeListener(_onMarkerAnimationTick)
      ..dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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
    _animatedTrackedMarker = _buildTrackedMarker(
      position: interpolated,
      rotation: rotation,
      isDriverTracking: _animationIsDriverTracking,
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
        return l10n.translate('status_offer_selected');
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      default:
        return l10n.translate('status_in_progress');
    }
  }

  String _tripStageText(Map<String, dynamic> request) {
    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return l10n.translate('awaiting_driver_assignment');
      case 'pending_pickup':
        return l10n.translate('driver_heading_to_pickup');
      case 'picked_up':
        return l10n.translate('picked_up');
      case 'on_the_way':
        return l10n.translate('driver_on_the_way_to_you');
      case 'delivered':
        return l10n.translate('status_delivered');
      default:
        if (status == 'assigned') return l10n.translate('status_offer_selected');
        if (status == 'shipped') return l10n.translate('driver_on_the_way_to_you');
        if (status == 'delivered') return l10n.translate('status_delivered');
        return l10n.translate('preparing_request');
    }
  }

  IconData _tripStageIcon(Map<String, dynamic> request) {
    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return Icons.person_search_outlined;
      case 'pending_pickup':
        return Icons.store_mall_directory_outlined;
      case 'picked_up':
        return Icons.inventory_2_outlined;
      case 'on_the_way':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.verified_outlined;
      default:
        if (status == 'shipped') return Icons.local_shipping_outlined;
        if (status == 'delivered') return Icons.verified_outlined;
        return Icons.timelapse_outlined;
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
    return '$raw ${l10n.translate('sar')}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return l10n.translate('now');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${l10n.translate('minute_unit')}';
    }
    return '${diff.inHours} ${l10n.translate('hour_unit')}';
  }

  String _formatSpeed(double? speedKmh) {
    if (speedKmh == null || !speedKmh.isFinite || speedKmh <= 0) {
      return '0 ${l10n.translate('km_per_hour')}';
    }
    return '${speedKmh.toStringAsFixed(0)} ${l10n.translate('km_per_hour')}';
  }

  String _formatAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null || !accuracyMeters.isFinite || accuracyMeters <= 0) {
      return l10n.translate('unknown');
    }
    if (accuracyMeters < 10) {
      return '${accuracyMeters.toStringAsFixed(0)} ${l10n.translate('meter_short')}';
    }
    return '${accuracyMeters.toStringAsFixed(0)} ${l10n.translate('meter')}';
  }

  int _tripStageIndex(Map<String, dynamic> request) {
    final deliveryStatus = (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

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
        _distanceMeters(_lastRouteOrigin!, origin) >= _driverRouteRefreshMeters;

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
      // ignore
    } finally {
      _isLoadingRoute = false;
    }
  }

  Future<void> _fitDriverAndTarget() async {
    final controller = _mapController;
    final driver = _animatedTrackedPosition;
    final target = _lastRouteDestination ?? _requestTargetLatLng(widget.request);

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
            title: l10n.translate('worker_chat'),
          ),
        ),
      );
    } catch (e) {
      _showSnack('${l10n.translate('open_chat_failed')}: $e');
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
      _showSnack(l10n.translate('worker_phone_not_available'));
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    _showSnack(l10n.translate('unable_to_make_call'));
  }

  Future<void> _openMapUrl(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _showSnack(l10n.translate('unable_to_open_location'));
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
        _distanceMeters(_lastTrackedLocation!, position) <
            _cameraMoveThresholdMeters) {
      return;
    }

    _lastCameraMoveAt = now;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: _cameraZoomFollow,
            bearing: rotation,
            tilt: _cameraTiltFollow,
          ),
        ),
      );
    } catch (_) {}
  }

  Marker _buildTrackedMarker({
    required LatLng position,
    required double rotation,
    required bool isDriverTracking,
  }) {
    return Marker(
      markerId: const MarkerId('tracked'),
      position: position,
      rotation: rotation,
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
        title: isDriverTracking
            ? l10n.translate('driver')
            : l10n.translate('worker'),
      ),
    );
  }

  void _animateTrackedMarker({
    required LatLng livePosition,
    required bool isDriverTracking,
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
      _animatedTrackedMarker = _buildTrackedMarker(
        position: livePosition,
        rotation: targetRotation,
        isDriverTracking: isDriverTracking,
      );
      return;
    }

    final movement = _distanceMeters(previousPosition, livePosition);
    if (movement < 1.5) {
      _animatedTrackedPosition = livePosition;
      _animatedRotation = targetRotation;
      _animatedTrackedMarker = _buildTrackedMarker(
        position: livePosition,
        rotation: targetRotation,
        isDriverTracking: isDriverTracking,
      );
      return;
    }

    _animationStartPosition = previousPosition;
    _animationEndPosition = livePosition;
    _animationStartRotation = _animatedRotation;
    _animationEndRotation = targetRotation;
    _animationIsDriverTracking = isDriverTracking;

    _markerAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  Widget _buildTrackingMap(Map<String, dynamic> request) {
    final driverId = _driverIdFromRequest(request);
    final workerId = _workerIdFromRequest(request);

    final trackingId = driverId.isNotEmpty ? driverId : workerId;
    final isDriverTracking = driverId.isNotEmpty;

    if (trackingId.isEmpty) {
      return _MapPlaceholder(
        title: l10n.translate('cannot_show_tracking_now'),
        subtitle: l10n.translate('no_worker_or_driver_linked_yet'),
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

        if (snapshot.connectionState == ConnectionState.waiting &&
            _animatedTrackedMarker == null) {
          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (data == null && _animatedTrackedMarker == null) {
          return _MapPlaceholder(
            title: l10n.translate('waiting_for_tracking_start'),
            subtitle: isDriverTracking
                ? l10n.translate('driver_location_will_appear')
                : l10n.translate('worker_location_will_appear'),
            icon: Icons.hourglass_empty,
          );
        }

        final lat = _readDouble(data?['lat']);
        final lng = _readDouble(data?['lng']);
        final heading = _readDouble(data?['heading']);
        final speedMps = _readDouble(data?['speed']);
        final accuracyMeters = _readDouble(data?['accuracy']);

        if ((lat == null || lng == null) && _animatedTrackedMarker == null) {
          return _MapPlaceholder(
            title: l10n.translate('location_not_available'),
            subtitle: isDriverTracking
                ? l10n.translate('driver_has_not_started_tracking')
                : l10n.translate('worker_has_not_started_tracking'),
            icon: Icons.location_disabled,
          );
        }

        if (lat != null && lng != null) {
          final trackedPosition = LatLng(lat, lng);
          final target = _requestTargetLatLng(request);

          _lastTrackedLocation = trackedPosition;
          _lastSpeedKmh = speedMps == null ? null : (speedMps * 3.6);
          _lastAccuracyMeters = accuracyMeters;

          final updatedAt = data?['updatedAt'];
          if (updatedAt is Timestamp) {
            _lastUpdatedAt = updatedAt.toDate();
          }

          _animateTrackedMarker(
            livePosition: trackedPosition,
            isDriverTracking: isDriverTracking,
            heading: heading,
          );

          if (target != null) {
            _scheduleRouteRefresh(trackedPosition, target);
          }
        }

        final target = _requestTargetLatLng(request);

        final markers = <Marker>{
          if (_animatedTrackedMarker != null) _animatedTrackedMarker!,
          if (target != null)
            Marker(
              markerId: const MarkerId('target'),
              position: target,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: l10n.translate('delivery_location'),
              ),
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

        final initialTarget = _animatedTrackedPosition ??
            _lastTrackedLocation ??
            target ??
            const LatLng(26.4207, 50.0888);

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
                  markers: markers,
                  polylines: polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  buildingsEnabled: true,
                  trafficEnabled: true,
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
                          Text('${l10n.translate('time')}: ${_route!.etaLabel}'),
                          Text('${l10n.translate('distance')}: ${_route!.distanceLabel}'),
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
                      _followDriver
                          ? l10n.translate('auto_follow_on')
                          : l10n.translate('auto_follow_off'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
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
                    '${l10n.translate('last_update')}: ${_formatTime(_lastUpdatedAt!)}',
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

                      final trackedLocation = _animatedTrackedPosition;
                      if (_followDriver && trackedLocation != null) {
                        _followTrackedPosition(
                          trackedLocation,
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
                    heroTag: 'center_driver_btn',
                    onPressed: () {
                      final trackedLocation = _animatedTrackedPosition;
                      if (_mapController != null && trackedLocation != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(trackedLocation),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'fit_driver_target_btn',
                    onPressed: _fitDriverAndTarget,
                    child: const Icon(Icons.fit_screen_outlined),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'map_type_toggle_btn',
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

  Widget _buildTripProgress(Map<String, dynamic> request) {
    final stages = [
      l10n.translate('assign_driver'),
      l10n.translate('pickup'),
      l10n.translate('start_delivery'),
      l10n.translate('on_the_way'),
      l10n.translate('delivery'),
    ];
    final currentIndex = _tripStageIndex(request);

    return Column(
      children: [
        Row(
          children: List.generate(stages.length, (index) {
            final isActive = index <= currentIndex;
            return Expanded(
              child: Container(
                margin: EdgeInsetsDirectional.only(
                  end: index == stages.length - 1 ? 0 : 6,
                ),
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.white12,
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
      return Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: Text(l10n.translate('unable_load_request')),
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
            ((request['scrapyardName'] ?? '').toString().trim().isEmpty)
                ? l10n.translate('not_specified')
                : (request['scrapyardName'] ?? '').toString();

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
                                Text(
                                  l10n.translate('track_request'),
                                  style: const TextStyle(
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
                                  Text(
                                    l10n.translate('current_status'),
                                    style: const TextStyle(
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
                                color: _statusColor(status).withValues(alpha: 0.16),
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
                            Row(
                              children: [
                                Icon(
                                  _tripStageIcon(request),
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _tripStageText(request),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildTripProgress(request),
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
                            Text(
                              l10n.translate('live_map'),
                              style: const TextStyle(
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
                              label: l10n.translate('requested_part'),
                              value: (request['partName'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: l10n.translate('vehicle'),
                              value:
                                  '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                            ),
                            _InfoRow(
                              label: l10n.translate('selected_price'),
                              value: _priceText(request),
                            ),
                            _InfoRow(
                              label: l10n.translate('city'),
                              value: (request['city'] ?? '-').toString(),
                            ),
                            _InfoRow(
                              label: l10n.translate('scrapyard'),
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
                                  label: Text(l10n.translate('open_scrapyard_location')),
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
                              Text(
                                l10n.translate('delivery_address'),
                                style: const TextStyle(
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
                                  '${l10n.translate('coordinates')}: ${deliveryLat.toStringAsFixed(6)}, ${deliveryLng.toStringAsFixed(6)}',
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
                            Text(
                              l10n.translate('request_actions'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              status == 'assigned'
                                  ? l10n.translate('request_actions_assigned')
                                  : status == 'shipped'
                                      ? l10n.translate('request_actions_shipped')
                                      : status == 'delivered'
                                          ? l10n.translate('request_actions_delivered')
                                          : l10n.translate('request_actions_default'),
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
                                      ? l10n.translate('worker_chat')
                                      : l10n.translate('chat_available_after_accept'),
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
                                label: Text(l10n.translate('call_worker')),
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