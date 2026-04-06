import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../profile/worker_profile_screen.dart';
import '../requests/worker_request_details_screen.dart';
import '../vehicles/add_vehicle_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VehicleProvider>().listenToMyVehicles();
      context.read<RequestProvider>().listenToWorkerRequests();
    });
  }

  @override
  void dispose() {
    context.read<RequestProvider>().stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _WorkerOverviewTab(),
      const _WorkerRequestsTab(),
      const _WorkerVehiclesTab(),
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
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'مركباتي',
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

class _WorkerVehiclesTab extends StatelessWidget {
  const _WorkerVehiclesTab();

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    if (vehicleProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (vehicleProvider.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('مركباتي'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              vehicleProvider.errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddVehicleScreen(),
              ),
            );

            if (created == true && context.mounted) {
              context.read<VehicleProvider>().listenToMyVehicles();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة مركبة'),
        ),
      );
    }

    final vehicles = vehicleProvider.vehicles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركباتي'),
      ),
      body: vehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد مركبات مضافة بعد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'أضف مركبتك وارفع الصور حتى تظهر للإدارة للمراجعة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                context.read<VehicleProvider>().listenToMyVehicles();
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];

                  final make = (vehicle['make'] ?? '').toString();
                  final model = (vehicle['model'] ?? '').toString();
                  final year = (vehicle['year'] ?? '').toString();
                  final city = (vehicle['city'] ?? '').toString();
                  final status = (vehicle['status'] ?? '').toString();
                  final coverImage = (vehicle['coverImage'] ??
                          vehicle['cover'] ??
                          vehicle['vehicleCoverImage'] ??
                          '')
                      .toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (coverImage.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: Image.network(
                              coverImage,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: double.infinity,
                                  height: 180,
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: const BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              size: 48,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$make $model $year',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusText(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _VehicleInfoRow(
                                label: 'المدينة',
                                value: city.isEmpty ? '-' : city,
                              ),
                              _VehicleInfoRow(
                                label: 'نوع الضرر',
                                value: _damageTypeText(
                                  (vehicle['damageType'] ?? '').toString(),
                                ),
                              ),
                              _VehicleInfoRow(
                                label: 'التشليح',
                                value:
                                    (vehicle['scrapyardName'] ?? '-').toString(),
                                isLast: true,
                              ),
                              if ((vehicle['visibleParts'] as List?) != null &&
                                  (vehicle['visibleParts'] as List).isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (vehicle['visibleParts'] as List)
                                      .map(
                                        (part) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            part.toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddVehicleScreen(),
            ),
          );

          if (created == true && context.mounted) {
            context.read<VehicleProvider>().listenToMyVehicles();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة مركبة'),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'published':
        return 'منشورة';
      case 'pending':
        return 'قيد المراجعة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return 'غير محدد';
    }
  }

  String _damageTypeText(String value) {
    switch (value) {
      case 'front':
        return 'أمامي';
      case 'rear':
        return 'خلفي';
      case 'leftSide':
        return 'جهة يسار';
      case 'rightSide':
        return 'جهة يمين';
      case 'rollover':
        return 'انقلاب';
      case 'flood':
        return 'غرق';
      case 'fire':
        return 'حريق';
      default:
        return 'غير محدد';
    }
  }
}

class _WorkerOverviewTab extends StatelessWidget {
  const _WorkerOverviewTab();

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();
    final currentUserId = vehicleProvider.currentUserId ?? '';

    final myVehicles = vehicleProvider.vehicles.where((v) {
      final workerId = (v['workerId'] ?? '').toString().trim();
      return workerId == currentUserId;
    }).toList();

    final pendingVehicles = myVehicles
        .where((v) => (v['status'] ?? '') == 'pending')
        .toList();
    final publishedVehicles = myVehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();
    final rejectedVehicles = myVehicles
        .where((v) => (v['status'] ?? '') == 'rejected')
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
                        'أضف مركباتك من تبويب "مركباتي" ثم تابع مراجعتها واعتمادها من الإدارة.',
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
                        label: 'مركباتي',
                        value: myVehicles.length.toString(),
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
                        label: 'مرفوضة',
                        value: rejectedVehicles.length.toString(),
                        icon: Icons.cancel_outlined,
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
                        value: myVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: 'المركبات بانتظار الاعتماد',
                        value: pendingVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: 'المركبات المنشورة',
                        value: publishedVehicles.length.toString(),
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
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
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

class _VehicleInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _VehicleInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
