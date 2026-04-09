import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../providers/auth_provider.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<_CustomerProfileViewModel> _loadViewModel(String uid) async {
    final userFuture = _db.collection(FirestorePaths.users).doc(uid).get();

    final requestsFuture = _db
        .collection(FirestorePaths.requests)
        .where('customerId', isEqualTo: uid)
        .get();

    final favoritesFuture = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('favoriteWorkers')
        .get();

    final notificationsFuture = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final results = await Future.wait([
      userFuture,
      requestsFuture,
      favoritesFuture,
      notificationsFuture,
    ]);

    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final requestsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final favoritesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final notificationsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final userData = userDoc.data() ?? <String, dynamic>{};

    final name = (userData['name'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();

    final savedAddresses = <String>{};
    for (final doc in requestsSnap.docs) {
      final data = doc.data();
      final address = (data['deliveryAddress'] ?? '').toString().trim();
      if (address.isNotEmpty) {
        savedAddresses.add(address);
      }
    }

    return _CustomerProfileViewModel(
      name: name.isNotEmpty ? name : 'مستخدم',
      phone: phone.isNotEmpty ? phone : 'غير مضاف',
      email: email.isNotEmpty ? email : 'غير مضاف',
      requestsCount: requestsSnap.docs.length,
      favoritesCount: favoritesSnap.docs.length,
      unreadNotificationsCount: notificationsSnap.docs.length,
      savedAddresses: savedAddresses.toList(),
    );
  }

  Future<void> _saveProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _db.collection(FirestorePaths.users).doc(uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدعم الفني',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'إذا واجهت مشكلة أثناء الطلب أو تتبع الشحنة:\n'
                  '1) تأكد من اختيار عنوان صحيح.\n'
                  '2) تأكد من رقم التواصل.\n'
                  '3) راجع حالة الطلب من "طلباتي".\n'
                  '4) إذا لم يظهر التتبع فانتظر حتى يبدأ العامل مرحلة الشحن.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPersonalDataSheet({
    required String uid,
    required _CustomerProfileViewModel data,
  }) {
    final nameController = TextEditingController(text: data.name);
    final phoneController =
        TextEditingController(text: data.phone == 'غير مضاف' ? '' : data.phone);

    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'البيانات الشخصية',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      controller: nameController,
                      label: 'الاسم',
                      hint: 'اكتب اسمك',
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: phoneController,
                      label: 'رقم الجوال',
                      hint: '05xxxxxxxx',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final phone = phoneController.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('يرجى إدخال الاسم'),
                                    ),
                                  );
                                  return;
                                }

                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('يرجى إدخال رقم الجوال'),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                try {
                                  await _saveProfile(
                                    uid: uid,
                                    name: name,
                                    phone: phone,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  setState(() {});

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم حفظ البيانات بنجاح'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('فشل حفظ البيانات: $e'),
                                    ),
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => isSaving = false);
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  void _showAddressesSheet(List<String> addresses) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'العناوين المحفوظة',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: addresses.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'لا توجد عناوين محفوظة بعد.\nسيتم حفظ العناوين تلقائيًا عند إنشاء طلبات شحن جديدة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.7,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: addresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final address = addresses[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D21),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'آخر الإشعارات',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection(FirestorePaths.users)
                        .doc(uid)
                        .collection('notifications')
                        .orderBy('createdAt', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'لا توجد إشعارات حتى الآن',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = docs[index].data();
                          final title = (item['title'] ?? 'إشعار').toString();
                          final body = (item['body'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D21),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                            ),
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
                                const SizedBox(height: 8),
                                Text(
                                  body.isEmpty ? 'بدون تفاصيل' : body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.uid;

    if (uid == null || uid.isEmpty) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: Text('لا يوجد مستخدم مسجل'),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<_CustomerProfileViewModel>(
      future: _loadViewModel(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppGradientBackground(
              child: SafeArea(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: AppGradientBackground(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'فشل تحميل بيانات الحساب: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const _CustomerProfileViewModel.empty();

        return Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حسابي',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'أدر بياناتك وتابع طلباتك وإعدادات التطبيق من مكان واحد',
                            style: TextStyle(color: Colors.white70, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF20252B), Color(0xFF171A1F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.person, size: 34),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data.phone,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data.email,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'عميل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              label: 'طلباتي',
                              value: data.requestsCount.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: 'العناوين',
                              value: data.savedAddresses.length.toString(),
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: 'الإشعارات',
                              value: data.unreadNotificationsCount.toString(),
                              icon: Icons.notifications_none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        'الإعدادات',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: 'البيانات الشخصية',
                            subtitle: 'تعديل الاسم ورقم الجوال ومعلومات الحساب',
                            onTap: () => _showPersonalDataSheet(
                              uid: uid,
                              data: data,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            title: 'العناوين',
                            subtitle: 'عرض العناوين المحفوظة من طلبات الشحن السابقة',
                            onTap: () => _showAddressesSheet(data.savedAddresses),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'الإشعارات',
                            subtitle: 'اعرض آخر الإشعارات المرتبطة بطلباتك',
                            onTap: () => _showNotificationsSheet(uid),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.support_agent_outlined,
                            title: 'الدعم الفني',
                            subtitle: 'مساعدة سريعة لحل أبرز مشاكل الطلب والتتبع',
                            onTap: _showSupportSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2B1D1D),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  await context.read<AuthProvider>().signOut();
                                },
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('تسجيل الخروج'),
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

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerProfileViewModel {
  final String name;
  final String phone;
  final String email;
  final int requestsCount;
  final int favoritesCount;
  final int unreadNotificationsCount;
  final List<String> savedAddresses;

  const _CustomerProfileViewModel({
    required this.name,
    required this.phone,
    required this.email,
    required this.requestsCount,
    required this.favoritesCount,
    required this.unreadNotificationsCount,
    required this.savedAddresses,
  });

  const _CustomerProfileViewModel.empty()
      : name = 'مستخدم',
        phone = 'غير مضاف',
        email = 'غير مضاف',
        requestsCount = 0,
        favoritesCount = 0,
        unreadNotificationsCount = 0,
        savedAddresses = const [];
}