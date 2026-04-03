import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../finance/admin_commissions_screen.dart';
import '../requests/admin_request_offers_screen.dart';
import '../review/review_vehicle_screen.dart';
import '../workers/manage_workers_screen.dart';

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

class _AdminRequestsTab extends StatelessWidget {
  const _AdminRequestsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final requests = provider.requests;

    if (requests.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'لا توجد طلبات حاليًا',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات العملاء'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = requests[index];
          final partName = (request['partName'] ?? 'طلب بدون اسم').toString();
          final customerName = (request['customerName'] ?? 'عميل').toString();
          final status = (request['status'] ?? '').toString();

          return Card(
            child: ListTile(
              title: Text(partName),
              subtitle: Text('العميل: $customerName\nالحالة: $status'),
              isThreeLine: true,
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminRequestOffersScreen(request: request),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AdminOverviewTab extends StatelessWidget {
  const _AdminOverviewTab();

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();

    final allVehicles = vehicleProvider.vehicles;
    final pendingVehicles = allVehicles
        .where((v) => (v['status'] ?? '') == 'pending')
        .toList();
    final publishedVehicles = allVehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();

    final allRequests = requestProvider.requests;
    final newRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'newRequest')
        .toList();
    final checkingRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'checkingAvailability')
        .toList();
    final availableRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'available')
        .toList();

    return AppGradientBackground(
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
                      'لوحة تحكم المدير',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'تابع الطلبات والعمال والمالية والمراجعات من مكان واحد',
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نظرة تشغيلية',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'هذه الشاشة تعطيك ملخصًا سريعًا، وباقي التبويبات مخصصة للتنفيذ والإدارة.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.4,
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
                      child: StatCard(
                        label: 'كل المركبات',
                        value: allVehicles.length.toString(),
                        icon: Icons.directions_car_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'قيد المراجعة',
                        value: pendingVehicles.length.toString(),
                        icon: Icons.hourglass_top_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'منشورة',
                        value: publishedVehicles.length.toString(),
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'طلبات جديدة',
                        value: newRequests.length.toString(),
                        icon: Icons.fiber_new_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'جاري التحقق',
                        value: checkingRequests.length.toString(),
                        icon: Icons.search_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'متوفرة',
                        value: availableRequests.length.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    children: [
                      _AdminActionRow(
                        icon: Icons.assignment_outlined,
                        title: 'الطلبات',
                        subtitle: 'راجع عروض الطلبات وحالاتها',
                      ),
                      _AdminActionRow(
                        icon: Icons.groups_outlined,
                        title: 'العمال',
                        subtitle: 'إدارة الحسابات والاعتمادات',
                      ),
                      _AdminActionRow(
                        icon: Icons.payments_outlined,
                        title: 'المالية',
                        subtitle: 'متابعة العمولات والتقارير',
                      ),
                      _AdminActionRow(
                        icon: Icons.fact_check_outlined,
                        title: 'المراجعة',
                        subtitle: 'اعتماد المركبات والتحقق من البيانات',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _AdminActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
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
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}