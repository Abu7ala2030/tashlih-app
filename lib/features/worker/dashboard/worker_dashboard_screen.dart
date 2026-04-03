import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../profile/worker_profile_screen.dart';
import '../requests/worker_request_details_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _WorkerOverviewTab(),
      const _WorkerRequestsTab(),
      const WorkerProfileScreen(),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _WorkerRequestsTab extends StatelessWidget {
  const _WorkerRequestsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final currentUserId = provider.currentUserId ?? '';

    final workerRequests = provider.requests.where((request) {
      final assignedWorkerId =
          (request['assignedWorkerId'] ?? '').toString().trim();
      final workerId = (request['workerId'] ?? '').toString().trim();
      final acceptedWorkerId =
          (request['acceptedWorkerId'] ?? '').toString().trim();
      final listedByWorkerId =
          (request['listedByWorkerId'] ?? '').toString().trim();

      return assignedWorkerId == currentUserId ||
          workerId == currentUserId ||
          acceptedWorkerId == currentUserId ||
          listedByWorkerId == currentUserId;
    }).toList();

    if (workerRequests.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'لا توجد طلبات مسندة لك حاليًا',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: workerRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = workerRequests[index];
          final partName = (request['partName'] ?? 'طلب بدون اسم').toString();
          final vehicle =
              '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}';
          final status = (request['status'] ?? '').toString();

          return Card(
            child: ListTile(
              title: Text(partName),
              subtitle: Text('$vehicle\nالحالة: $status'),
              isThreeLine: true,
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerRequestDetailsScreen(request: request),
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

class _WorkerOverviewTab extends StatelessWidget {
  const _WorkerOverviewTab();

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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة العامل',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'تابع طلباتك وحالة مركباتك بسرعة',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
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
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جاهز للعمل',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'الطلبات الجديدة تظهر لك في تبويب الطلبات، وتستطيع متابعة حالتها من هنا.',
                        style: TextStyle(
                          fontSize: 19,
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: const Text(
                  'ملخص سريع',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'المركبات المضافة',
                        value: allVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: 'المركبات بانتظار الاعتماد',
                        value: pendingVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: 'الطلبات الجديدة',
                        value: newRequests.length.toString(),
                      ),
                      _SummaryRow(
                        label: 'الطلبات المتوفرة',
                        value: availableRequests.length.toString(),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}