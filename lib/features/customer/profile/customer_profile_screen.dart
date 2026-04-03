import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../providers/auth_provider.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  Future<_CustomerProfileData> _loadProfileData() async {
    final uid = FirebaseFirestore.instance.app.options.projectId.isNotEmpty
        ? null
        : null;

    final authUser = FirebaseFirestore.instance.app.name;
    // السطران أعلاه لا يُستخدمان، لكن الإبقاء عليهما غير ضروري.
    // سنعتمد مباشرة على AuthProvider من الواجهة.

    return const _CustomerProfileData.empty();
  }

  Future<_CustomerProfileViewModel> _loadViewModel(String uid) async {
    final db = FirebaseFirestore.instance;

    final userFuture =
        db.collection(FirestorePaths.users).doc(uid).get();

    final requestsFuture = db
        .collection(FirestorePaths.requests)
        .where('customerId', isEqualTo: uid)
        .get();

    final favoritesFuture = db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('favoriteWorkers')
        .get();

    final notificationsFuture = db
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

    return _CustomerProfileViewModel(
      name: name.isNotEmpty ? name : 'مستخدم',
      phone: phone.isNotEmpty ? phone : 'غير مضاف',
      email: email.isNotEmpty ? email : 'غير مضاف',
      requestsCount: requestsSnap.docs.length,
      favoritesCount: favoritesSnap.docs.length,
      unreadNotificationsCount: notificationsSnap.docs.length,
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title قريبًا')),
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
                              label: 'المحفوظات',
                              value: data.favoritesCount.toString(),
                              icon: Icons.bookmark_border,
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
                            subtitle: 'الاسم ورقم الجوال ومعلومات الحساب',
                            onTap: () => _showComingSoon(context, 'البيانات الشخصية'),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            title: 'العناوين',
                            subtitle: 'إدارة المدن والعناوين المرتبطة بطلباتك',
                            onTap: () => _showComingSoon(context, 'العناوين'),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.support_agent_outlined,
                            title: 'الدعم الفني',
                            subtitle: 'تواصل مع الدعم عند وجود مشكلة أو استفسار',
                            onTap: () => _showComingSoon(context, 'الدعم الفني'),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.settings_outlined,
                            title: 'إعدادات التطبيق',
                            subtitle: 'الإشعارات واللغة والتفضيلات العامة',
                            onTap: () => _showComingSoon(context, 'إعدادات التطبيق'),
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

class _CustomerProfileData {
  const _CustomerProfileData.empty();
}

class _CustomerProfileViewModel {
  final String name;
  final String phone;
  final String email;
  final int requestsCount;
  final int favoritesCount;
  final int unreadNotificationsCount;

  const _CustomerProfileViewModel({
    required this.name,
    required this.phone,
    required this.email,
    required this.requestsCount,
    required this.favoritesCount,
    required this.unreadNotificationsCount,
  });

  const _CustomerProfileViewModel.empty()
      : name = 'مستخدم',
        phone = 'غير مضاف',
        email = 'غير مضاف',
        requestsCount = 0,
        favoritesCount = 0,
        unreadNotificationsCount = 0;
}