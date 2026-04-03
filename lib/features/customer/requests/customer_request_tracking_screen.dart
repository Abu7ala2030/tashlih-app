// (تم اختصار الاستيرادات غير المعدلة)
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

  LatLng? _requestTargetLatLng(Map<String, dynamic> request) {
    final lat = request['deliveryLat'] ?? request['lat'];
    final lng = request['deliveryLng'] ?? request['lng'];

    if (lat == null || lng == null) return null;
    return LatLng(lat * 1.0, lng * 1.0);
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
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Widget _buildTrackingMap(Map<String, dynamic> request) {
    final workerId = _workerIdFromRequest(request);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        if (data == null) {
          return const SizedBox(
            height: 260,
            child: Center(child: Text('بانتظار بدء التتبع')),
          );
        }

        final lat = data['lat'];
        final lng = data['lng'];

        if (lat == null || lng == null) {
          return const SizedBox(
            height: 260,
            child: Center(child: Text('الموقع غير متوفر')),
          );
        }

        final worker = LatLng(lat * 1.0, lng * 1.0);
        final target = _requestTargetLatLng(request);

        _lastWorkerLocation = worker;

        final updatedAt = data['updatedAt'];
        if (updatedAt is Timestamp) {
          _lastUpdatedAt = updatedAt.toDate();
        }

        if (target != null) {
          _updateRoute(worker, target);
        }

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('worker'),
            position: worker,
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
                  color: Colors.blue,
                )
              };

        return Stack(
          children: [
            SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: worker,
                  zoom: 14,
                ),
                markers: markers,
                polylines: polylines,
                onMapCreated: (c) => _mapController = c,
              ),
            ),

            /// ETA BOX
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

            /// زر التركيز
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_mapController != null &&
                      _lastWorkerLocation != null) {
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
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text('تتبع الطلب',
                  style: TextStyle(fontSize: 24)),
              Expanded(
                child: _buildTrackingMap(widget.request),
              ),
            ],
          ),
        ),
      ),
    );
  }
}