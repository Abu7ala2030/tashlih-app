import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import 'admin_driver_live_map_screen.dart';

class AdminDriverLiveScreen extends StatelessWidget {
  final String driverId;

  const AdminDriverLiveScreen({
    super.key,
    required this.driverId,
  });

  Future<Map<String, dynamic>?> _loadDriverFallback() async {
    final userDoc = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(driverId)
        .get();

    return userDoc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirestorePaths.drivers)
                .doc(driverId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final liveDriver = snapshot.data?.data();

              if (liveDriver == null) {
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
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'تعذر تحميل بيانات السائق',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return _DriverLiveBody(
                      driverId: driverId,
                      driver: fallbackData,
                    );
                  },
                );
              }

              return _DriverLiveBody(
                driverId: driverId,
                driver: liveDriver,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DriverLiveBody extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> driver;

  const _DriverLiveBody({
    required this.driverId,
    required this.driver,
  });

  @override
  Widget build(BuildContext context) {
    final currentRequestId = (driver['currentRequestId'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'حالة السائق المباشرة',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        _DriverStatusCard(driver: driver),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminDriverLiveMapScreen(
                  driverId: driverId,
                  initialRequestId:
                      currentRequestId.isEmpty ? null : currentRequestId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('فتح الخريطة المباشرة'),
        ),
        const SizedBox(height: 20),
        if (currentRequestId.isNotEmpty)
          _CurrentRequestCard(requestId: currentRequestId)
        else
          const _EmptyCard(text: 'لا يوجد طلب حالي'),
      ],
    );
  }
}

class _DriverStatusCard extends StatelessWidget {
  final Map<String, dynamic> driver;

  const _DriverStatusCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final status = (driver['status'] ?? '').toString();
    final isOnline = driver['isOnline'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isOnline
                ? Colors.green.withOpacity(.2)
                : Colors.grey.withOpacity(.2),
            child: Icon(
              Icons.local_shipping,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isOnline ? 'متصل' : 'غير متصل',
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _statusText(status),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'onTheWay':
        return 'في الطريق للاستلام';
      case 'delivering':
        return 'يقوم بالتوصيل';
      case 'picked_up':
        return 'تم الاستلام';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }
}

class _CurrentRequestCard extends StatelessWidget {
  final String requestId;

  const _CurrentRequestCard({required this.requestId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.requests)
          .doc(requestId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() ?? {};

        final partName = (data['partName'] ?? '').toString();
        final customer = (data['customerName'] ?? '').toString();
        final city = (data['city'] ?? '').toString();
        final status = (data['status'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الطلب الحالي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text('القطعة: $partName'),
              Text('العميل: $customer'),
              if (city.isNotEmpty) Text('المدينة: $city'),
              const SizedBox(height: 8),
              _RequestStatusBadge(status: status),
            ],
          ),
        );
      },
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  final String status;

  const _RequestStatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Color _statusColor(String status) {
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

  String _statusText(String status) {
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
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text),
    );
  }
}