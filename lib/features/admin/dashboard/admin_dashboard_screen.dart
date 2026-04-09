import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../finance/admin_commissions_screen.dart';
import '../requests/admin_request_offers_screen.dart';
import '../review/review_vehicle_screen.dart';
import '../workers/manage_workers_screen.dart';
import 'models/admin_dashboard_stats.dart';
import 'models/admin_recent_request.dart';
import 'services/admin_dashboard_service.dart';
import 'widgets/admin_metric_card.dart';
import 'widgets/admin_recent_request_tile.dart';
import 'widgets/admin_worker_summary_tile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _AdminOverviewTab(),
      const _AdminRequestsTab(),
      const ManageWorkersScreen(),
      const AdminCommissionsScreen(),
      const ReviewVehicleScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'الطلبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'العمال',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'المالية',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'المراجعة',
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewTab extends StatefulWidget {
  const _AdminOverviewTab();

  @override
  State<_AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<_AdminOverviewTab> {
  final AdminDashboardService _service = AdminDashboardService();
  late Future<AdminDashboardBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.loadDashboardData();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.loadDashboardData();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientBackground(
      child: SafeArea(
        child: FutureBuilder<AdminDashboardBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'فشل تحميل لوحة المدير:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final bundle = snapshot.data ??
                AdminDashboardBundle(
                  stats: AdminDashboardStats.empty(),
                  recentRequests: [],
                  topWorkers: [],
                );

            final stats = bundle.stats;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  const Text(
                    'لوحة تحكم المدير',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نظرة تشغيلية مباشرة على الطلبات والإيرادات والعمال',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الملخص التنفيذي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'إجمالي الطلبات ${stats.totalRequests} • الإيرادات ${stats.totalRevenue.toStringAsFixed(2)} ر.س • العمولات ${stats.totalCommission.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      AdminMetricCard(
                        label: 'إجمالي الطلبات',
                        value: stats.totalRequests.toString(),
                        icon: Icons.assignment_outlined,
                      ),
                      AdminMetricCard(
                        label: 'طلبات جديدة',
                        value: stats.newRequests.toString(),
                        icon: Icons.fiber_new_outlined,
                      ),
                      AdminMetricCard(
                        label: 'طلبات نشطة',
                        value: stats.activeRequests.toString(),
                        icon: Icons.timelapse_outlined,
                      ),
                      AdminMetricCard(
                        label: 'طلبات مكتملة',
                        value: stats.completedRequests.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                      AdminMetricCard(
                        label: 'إيراد اليوم',
                        value: '${stats.todayRevenue.toStringAsFixed(0)} ر.س',
                        icon: Icons.today_outlined,
                      ),
                      AdminMetricCard(
                        label: 'إيراد الأسبوع',
                        value: '${stats.weekRevenue.toStringAsFixed(0)} ر.س',
                        icon: Icons.date_range_outlined,
                      ),
                      AdminMetricCard(
                        label: 'إيراد الشهر',
                        value: '${stats.monthRevenue.toStringAsFixed(0)} ر.س',
                        icon: Icons.calendar_month_outlined,
                      ),
                      AdminMetricCard(
                        label: 'إجمالي العمولة',
                        value: '${stats.totalCommission.toStringAsFixed(0)} ر.س',
                        icon: Icons.payments_outlined,
                      ),
                      AdminMetricCard(
                        label: 'عدد العمال',
                        value: stats.totalWorkers.toString(),
                        icon: Icons.groups_2_outlined,
                        subtitle: 'المتصلون: ${stats.onlineWorkers}',
                      ),
                      AdminMetricCard(
                        label: 'عدد السائقين',
                        value: stats.totalDrivers.toString(),
                        icon: Icons.local_shipping_outlined,
                        subtitle: 'المتصلون: ${stats.onlineDrivers}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'آخر الطلبات',
                    subtitle: 'أحدث 10 طلبات في المنصة',
                  ),
                  const SizedBox(height: 12),
                  if (bundle.recentRequests.isEmpty)
                    const _EmptyCard(
                      text: 'لا توجد طلبات حديثة حالياً',
                    )
                  else
                    ...bundle.recentRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminRecentRequestTile(request: request),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'أفضل العمال',
                    subtitle: 'حسب الطلبات المكتملة ثم الإيراد',
                  ),
                  const SizedBox(height: 12),
                  if (bundle.topWorkers.isEmpty)
                    const _EmptyCard(
                      text: 'لا توجد بيانات كافية عن العمال حالياً',
                    )
                  else
                    ...bundle.topWorkers.map(
                      (worker) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminWorkerSummaryTile(worker: worker),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminRequestsTab extends StatelessWidget {
  const _AdminRequestsTab();

  @override
  Widget build(BuildContext context) {
    return AppGradientBackground(
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(FirestorePaths.requests)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'فشل تحميل الطلبات:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد طلبات حاليًا',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: docs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مراقبة الطلبات',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'عرض مباشر لجميع طلبات العملاء وحالاتها',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final doc = docs[index - 1];
                final request = {
                  'id': doc.id,
                  ...doc.data(),
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminRecentRequestTile(
                    request: _requestFromMap(request),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminRequestOffersScreen(
                            request: request,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  AdminRecentRequest _requestFromMap(Map<String, dynamic> data) {
    return AdminRecentRequest(
      id: (data['id'] ?? '').toString(),
      partName: (data['partName'] ?? 'طلب بدون اسم').toString(),
      customerName: (data['customerName'] ?? 'عميل').toString(),
      city: (data['city'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      workerId: (data['workerId'] ?? '').toString(),
      driverId: (data['assignedDriverId'] ?? '').toString(),
      amount: _readAmount(data),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  double _readAmount(Map<String, dynamic> data) {
    final candidates = [
      data['acceptedOfferPrice'],
      data['totalPrice'],
      data['price'],
      data['amount'],
      data['bestOfferPrice'],
    ];

    for (final value in candidates) {
      if (value is num && value.toDouble() > 0) return value.toDouble();
      final parsed = double.tryParse((value ?? '').toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    return 0;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
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
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}