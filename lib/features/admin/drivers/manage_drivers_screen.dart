import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';

class ManageDriversScreen extends StatelessWidget {
  const ManageDriversScreen({super.key});

  Future<void> _toggleDriver({
    required String uid,
    required bool isActive,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
      'isOnline': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'driver')
                .snapshots(),
            builder: (context, snapshot) {
              final drivers = snapshot.data?.docs ?? [];

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (drivers.isEmpty) {
                return const Center(
                  child: Text(
                    'لا يوجد سائقين حاليًا',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: drivers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = drivers[index];
                  final data = doc.data();
                  final uid = doc.id;

                  final name = (data['name'] ?? 'سائق').toString();
                  final email = (data['email'] ?? '').toString();
                  final phone = (data['phone'] ?? '').toString();
                  final isActive = data['isActive'] == true;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              isActive ? Colors.green : Colors.grey,
                          child: const Icon(Icons.local_shipping),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                isActive ? 'نشط وجاهز' : 'غير نشط',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            _toggleDriver(uid: uid, isActive: value);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}