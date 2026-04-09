import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import 'admin_worker_details_screen.dart';
import '../drivers/admin_driver_live_screen.dart';

class ManageWorkersScreen extends StatefulWidget {
  const ManageWorkersScreen({super.key});

  @override
  State<ManageWorkersScreen> createState() => _ManageWorkersScreenState();
}

class _ManageWorkersScreenState extends State<ManageWorkersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة العمال والسائقين',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'متابعة الحسابات والحالة التشغيلية بشكل مباشر',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'العمال'),
                    Tab(text: 'السائقون'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _PeopleTab(
                    primaryCollection: FirestorePaths.workers,
                    fallbackRole: 'worker',
                    emptyText: 'لا يوجد عمال حالياً',
                    icon: Icons.person,
                    role: 'worker',
                  ),
                  _PeopleTab(
                    primaryCollection: FirestorePaths.drivers,
                    fallbackRole: 'driver',
                    emptyText: 'لا يوجد سائقون حالياً',
                    icon: Icons.local_shipping,
                    role: 'driver',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  final String primaryCollection;
  final String fallbackRole;
  final String emptyText;
  final IconData icon;
  final String role;

  const _PeopleTab({
    required this.primaryCollection,
    required this.fallbackRole,
    required this.emptyText,
    required this.icon,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadPeople(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'فشل تحميل البيانات:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final people = snapshot.data ?? [];

        if (people.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: people.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final person = people[index];
            final name = _name(person);
            final phone = _phone(person);
            final isOnline = _isOnline(person);
            final rating = _rating(person);

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D21),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                onTap: () {
                  final id = (person['id'] ?? '').toString();

                  if (role == 'driver') {
                    // 🚚 صفحة الحالة المباشرة للسائق
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminDriverLiveScreen(driverId: id),
                      ),
                    );
                  } else {
                    // 👤 صفحة تفاصيل العامل
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminWorkerDetailsScreen(
                          personId: id,
                          role: role,
                          initialData: person,
                        ),
                      ),
                    );
                  }
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: isOnline
                      ? Colors.green.withOpacity(.12)
                      : Colors.white10,
                  child: Icon(
                    icon,
                    color: isOnline ? Colors.green : Colors.white,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(phone),
                      if (rating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('التقييم: ${rating.toStringAsFixed(1)}'),
                        ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? Colors.green.withOpacity(.12)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOnline ? 'متصل' : 'غير متصل',
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadPeople() async {
    final db = FirebaseFirestore.instance;

    final primary = await db.collection(primaryCollection).get();
    if (primary.docs.isNotEmpty) {
      return primary.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    }

    final fallback = await db
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: fallbackRole)
        .get();

    return fallback.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  String _name(Map<String, dynamic> data) {
    final candidates = [
      data['name'],
      data['fullName'],
      data['displayName'],
      data['scrapyardName'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    return 'بدون اسم';
  }

  String _phone(Map<String, dynamic> data) {
    final candidates = [data['phone'], data['mobile'], data['phoneNumber']];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    return 'بدون رقم';
  }

  bool _isOnline(Map<String, dynamic> data) {
    if (data['isOnline'] == true) return true;
    if (data['online'] == true) return true;
    if (data['availableNow'] == true) return true;

    final status = (data['availabilityStatus'] ?? data['status'] ?? '')
        .toString()
        .toLowerCase();

    return status == 'online' || status == 'active';
  }

  double _rating(Map<String, dynamic> data) {
    final raw = data['rating'] ?? data['averageRating'];
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString()) ?? 0;
  }
}
