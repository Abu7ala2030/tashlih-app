import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';

class ManageWorkersScreen extends StatelessWidget {
  const ManageWorkersScreen({super.key});

  Future<void> _toggleWorker({
    required String uid,
    required bool isActive,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isActive': isActive,
      'disabledByAdmin': !isActive,
      'disabledAt': isActive ? FieldValue.delete() : FieldValue.serverTimestamp(),
      'disabledReason': isActive ? FieldValue.delete() : 'Disabled by admin',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _confirmToggleWorker({
    required BuildContext context,
    required String uid,
    required String name,
    required bool currentIsActive,
  }) async {
    final nextValue = !currentIsActive;

    if (nextValue) {
      await _toggleWorker(uid: uid, isActive: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تعطيل حساب العامل'),
          content: Text(
            'هل أنت متأكد من تعطيل حساب "$name"؟\n\n'
            'لن يستطيع العامل الدخول للتطبيق إلا بعد إعادة التفعيل من الإدارة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تعطيل'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _toggleWorker(uid: uid, isActive: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'worker')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'حدث خطأ أثناء تحميل العمال:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final workers = snapshot.data?.docs ?? [];

              if (workers.isEmpty) {
                return const Center(
                  child: Text(
                    'لا يوجد عمال حاليًا',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = workers[index];
                  final data = doc.data();
                  final uid = doc.id;

                  final name = (data['name'] ?? 'عامل').toString();
                  final email = (data['email'] ?? '').toString();
                  final phone = (data['phone'] ?? '').toString();
                  final scrapyardName =
                      (data['scrapyardName'] ?? '').toString();
                  final city = (data['city'] ?? '').toString();

                  final isActive = data['isActive'] != false &&
                      data['disabledByAdmin'] != true;

                  final disabledByAdmin = data['disabledByAdmin'] == true;

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
                          child: const Icon(Icons.engineering),
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
                              if (scrapyardName.isNotEmpty)
                                Text(
                                  scrapyardName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (city.isNotEmpty)
                                Text(
                                  city,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                isActive
                                    ? 'نشط'
                                    : disabledByAdmin
                                        ? 'معطل من الإدارة'
                                        : 'غير نشط',
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
                            _confirmToggleWorker(
                              context: context,
                              uid: uid,
                              name: name,
                              currentIsActive: isActive,
                            );
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