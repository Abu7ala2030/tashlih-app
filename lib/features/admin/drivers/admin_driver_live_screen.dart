import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';

class AdminDriverLiveScreen extends StatelessWidget {
  final String driverId;

  const AdminDriverLiveScreen({
    super.key,
    required this.driverId,
  });

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
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final driver = snapshot.data!.data() ?? {};
              final currentRequestId =
                  (driver['currentRequestId'] ?? '').toString();

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

                  // 🟢 حالة السائق
                  _DriverStatusCard(driver: driver),

                  const SizedBox(height: 20),

                  // 📦 الطلب الحالي
                  if (currentRequestId.isNotEmpty)
                    _CurrentRequestCard(requestId: currentRequestId)
                  else
                    const _EmptyCard(text: 'لا يوجد طلب حالي'),
                ],
              );
            },
          ),
        ),
      ),
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
      default:
        return 'غير معروف';
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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(20),
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
            ],
          ),
        );
      },
    );
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
      ),
      child: Text(text),
    );
  }
}