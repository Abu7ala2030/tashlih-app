import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';

class ManageCustomersScreen extends StatelessWidget {
  const ManageCustomersScreen({super.key});

  Future<void> _toggleCustomer({
    required String uid,
    required bool isActive,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isActive': isActive,
      'disabledByAdmin': !isActive,
      'disabledAt':
          isActive ? FieldValue.delete() : FieldValue.serverTimestamp(),
      'disabledReason': isActive ? FieldValue.delete() : 'Disabled by admin',
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
                .where('role', isEqualTo: 'customer')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = snapshot.data?.docs ?? [];

              if (customers.isEmpty) {
                return const Center(
                  child: Text(
                    'لا يوجد عملاء حاليًا',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: customers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = customers[index];
                  final data = doc.data();
                  final uid = doc.id;

                  final name = (data['name'] ?? 'عميل').toString();
                  final email = (data['email'] ?? '').toString();
                  final phone = (data['phone'] ?? '').toString();
                  final isActive = data['isActive'] != false;

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
                          child: const Icon(Icons.person),
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
                              if (email.isNotEmpty)
                                Text(email,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              if (phone.isNotEmpty)
                                Text(phone,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text(
                                isActive ? 'نشط' : 'معطل من الإدارة',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            _toggleCustomer(uid: uid, isActive: value);
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