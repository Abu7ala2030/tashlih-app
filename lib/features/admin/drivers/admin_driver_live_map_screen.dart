import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';

class AdminDriverLiveMapScreen extends StatefulWidget {
  final String driverId;
  final String? initialRequestId;

  const AdminDriverLiveMapScreen({
    super.key,
    required this.driverId,
    this.initialRequestId,
  });

  @override
  State<AdminDriverLiveMapScreen> createState() =>
      _AdminDriverLiveMapScreenState();
}

class _AdminDriverLiveMapScreenState extends State<AdminDriverLiveMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _driverStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.drivers)
        .doc(widget.driverId)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadDriverFallback() async {
    final userDoc = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(widget.driverId)
        .get();

    return userDoc.data();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _requestDoc(
    String requestId,
  ) {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString());
  }

  LatLng? _extractDriverLatLng(Map<String, dynamic> data) {
    final directLat = _readDouble(data['currentLat']) ??
        _readDouble(data['liveLat']) ??
        _readDouble(data['lat']) ??
        _readDouble(data['latitude']);

    final directLng = _readDouble(data['currentLng']) ??
        _readDouble(data['liveLng']) ??
        _readDouble(data['lng']) ??
        _readDouble(data['longitude']);

    if (directLat != null && directLng != null) {
      return LatLng(directLat, directLng);
    }

    final location = data['currentLocation'];
    if (location is Map<String, dynamic>) {
      final lat = _readDouble(location['lat']) ?? _readDouble(location['latitude']);
      final lng = _readDouble(location['lng']) ?? _readDouble(location['longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return null;
  }

  LatLng? _extractDeliveryLatLng(Map<String, dynamic> data) {
    final lat = _readDouble(data['deliveryLat']) ??
        _readDouble(data['customerLat']) ??
        _readDouble(data['destinationLat']) ??
        _readDouble(data['lat']);

    final lng = _readDouble(data['deliveryLng']) ??
        _readDouble(data['customerLng']) ??
        _readDouble(data['destinationLng']) ??
        _readDouble(data['lng']);

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  String _driverName(Map<String, dynamic> data) {
    final candidates = [
      data['name'],
      data['fullName'],
      data['displayName'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    return 'السائق';
  }

  String _requestStatusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'متاح';
      case 'assigned':
        return 'مُعيَّن';
      case 'accepted':
        return 'مقبول';
      case 'shipped':
        return 'مشحون';
      case 'delivered':
        return 'تم التسليم';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }

  Color _requestStatusColor(String status) {
    switch (status) {
      case 'newRequest':
        return Colors.orange;
      case 'checkingAvailability':
        return Colors.amber;
      case 'available':
        return Colors.lightGreen;
      case 'assigned':
      case 'accepted':
      case 'shipped':
        return Colors.blue;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  Future<void> _fitMap({
    required LatLng driverLatLng,
    LatLng? targetLatLng,
  }) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;

    if (targetLatLng == null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: driverLatLng,
            zoom: 15,
          ),
        ),
      );
      return;
    }

    final southwest = LatLng(
      driverLatLng.latitude < targetLatLng.latitude
          ? driverLatLng.latitude
          : targetLatLng.latitude,
      driverLatLng.longitude < targetLatLng.longitude
          ? driverLatLng.longitude
          : targetLatLng.longitude,
    );

    final northeast = LatLng(
      driverLatLng.latitude > targetLatLng.latitude
          ? driverLatLng.latitude
          : targetLatLng.latitude,
      driverLatLng.longitude > targetLatLng.longitude
          ? driverLatLng.longitude
          : targetLatLng.longitude,
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: southwest,
          northeast: northeast,
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _driverStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final driverData = snapshot.data?.data();

              if (driverData == null) {
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _loadDriverFallback(),
                  builder: (context, fallbackSnapshot) {
                    if (fallbackSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final fallbackData = fallbackSnapshot.data ?? {};
                    if (fallbackData.isEmpty) {
                      return _ErrorView(
                        title: 'تعذر تحميل بيانات السائق',
                        subtitle: 'لم يتم العثور على بيانات للسائق في drivers أو users.',
                      );
                    }

                    return _MapContent(
                      mapController: _mapController,
                      fitMap: _fitMap,
                      driverId: widget.driverId,
                      driverData: fallbackData,
                      driverLatLng: _extractDriverLatLng(fallbackData),
                      currentRequestId: widget.initialRequestId ??
                          (fallbackData['currentRequestId'] ?? '').toString(),
                      driverName: _driverName(fallbackData),
                      requestDocLoader: _requestDoc,
                      deliveryLatLngExtractor: _extractDeliveryLatLng,
                      requestStatusText: _requestStatusText,
                      requestStatusColor: _requestStatusColor,
                    );
                  },
                );
              }

              return _MapContent(
                mapController: _mapController,
                fitMap: _fitMap,
                driverId: widget.driverId,
                driverData: driverData,
                driverLatLng: _extractDriverLatLng(driverData),
                currentRequestId:
                    widget.initialRequestId ?? (driverData['currentRequestId'] ?? '').toString(),
                driverName: _driverName(driverData),
                requestDocLoader: _requestDoc,
                deliveryLatLngExtractor: _extractDeliveryLatLng,
                requestStatusText: _requestStatusText,
                requestStatusColor: _requestStatusColor,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapContent extends StatelessWidget {
  final Completer<GoogleMapController> mapController;
  final Future<void> Function({
    required LatLng driverLatLng,
    LatLng? targetLatLng,
  }) fitMap;
  final String driverId;
  final Map<String, dynamic> driverData;
  final LatLng? driverLatLng;
  final String currentRequestId;
  final String driverName;
  final Future<DocumentSnapshot<Map<String, dynamic>>> Function(String requestId)
      requestDocLoader;
  final LatLng? Function(Map<String, dynamic>) deliveryLatLngExtractor;
  final String Function(String) requestStatusText;
  final Color Function(String) requestStatusColor;

  const _MapContent({
    required this.mapController,
    required this.fitMap,
    required this.driverId,
    required this.driverData,
    required this.driverLatLng,
    required this.currentRequestId,
    required this.driverName,
    required this.requestDocLoader,
    required this.deliveryLatLngExtractor,
    required this.requestStatusText,
    required this.requestStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    if (driverLatLng == null) {
      return _ErrorView(
        title: 'لا يوجد موقع مباشر للسائق',
        subtitle:
            'تأكد أن السائق يرسل currentLat/currentLng أو liveLat/liveLng أو currentLocation.',
      );
    }

    if (currentRequestId.trim().isEmpty) {
      return Column(
        children: [
          _TopBar(title: 'خريطة السائق المباشرة'),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: driverLatLng!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('driver'),
                      position: driverLatLng!,
                      infoWindow: InfoWindow(title: driverName),
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) {
                    if (!mapController.isCompleted) {
                      mapController.complete(controller);
                    }
                  },
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _OverlayInfoCard(
                    title: driverName,
                    subtitle: 'السائق متصل لكن لا يوجد طلب حالي مرتبط به',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: requestDocLoader(currentRequestId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: const [
              _TopBar(title: 'خريطة السائق المباشرة'),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        final requestData = snapshot.data?.data() ?? {};
        final deliveryLatLng = deliveryLatLngExtractor(requestData);

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('driver'),
            position: driverLatLng!,
            infoWindow: InfoWindow(title: driverName),
          ),
        };

        final polylines = <Polyline>{};

        if (deliveryLatLng != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('delivery'),
              position: deliveryLatLng,
              infoWindow: const InfoWindow(title: 'موقع التسليم'),
            ),
          );

          polylines.add(
            Polyline(
              polylineId: const PolylineId('driver_to_delivery'),
              points: [driverLatLng!, deliveryLatLng],
              width: 4,
            ),
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            fitMap(
              driverLatLng: driverLatLng!,
              targetLatLng: deliveryLatLng,
            );
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            fitMap(driverLatLng: driverLatLng!);
          });
        }

        final partName = (requestData['partName'] ?? 'طلب بدون اسم').toString();
        final customerName = (requestData['customerName'] ?? 'عميل').toString();
        final status = (requestData['status'] ?? '').toString();
        final city = (requestData['city'] ?? '').toString();

        return Column(
          children: [
            const _TopBar(title: 'خريطة السائق المباشرة'),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: driverLatLng!,
                      zoom: 15,
                    ),
                    markers: markers,
                    polylines: polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      if (!mapController.isCompleted) {
                        mapController.complete(controller);
                      }
                    },
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _OverlayInfoCard(
                      title: driverName,
                      subtitle:
                          '$partName • $customerName${city.trim().isNotEmpty ? ' • $city' : ''}',
                      trailing: _StatusBadge(
                        label: requestStatusText(status),
                        color: requestStatusColor(status),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _BottomHintCard(
                      text: deliveryLatLng == null
                          ? 'تم تحديد موقع السائق فقط. لم يتم العثور على إحداثيات التسليم داخل الطلب.'
                          : 'الخريطة تعرض السائق وموقع التسليم مع خط مباشر بينهما.',
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
}

class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _OverlayInfoCard({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
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
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _BottomHintCard extends StatelessWidget {
  final String text;

  const _BottomHintCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.4,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ErrorView({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
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
    );
  }
}