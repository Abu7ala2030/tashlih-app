import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DriverOverviewTab(),
      const _DriverAssignedOrdersTab(),
      const _DriverProfileTab(),
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
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'طلباتي',
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

class _DriverOverviewTab extends StatelessWidget {
  const _DriverOverviewTab();

  bool _belongsToDriver(Map<String, dynamic> request, String currentUserId) {
    final assignedDriverId =
        (request['assignedDriverId'] ?? '').toString().trim();
    final driverId = (request['driverId'] ?? '').toString().trim();

    return assignedDriverId == currentUserId || driverId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RequestProvider>();
    final currentUserId = auth.uid ?? '';

    final driverRequests = provider.requests
        .where((request) => _belongsToDriver(request, currentUserId))
        .toList();

    final pendingPickup = driverRequests.where((request) {
      final deliveryStatus =
          (request['deliveryStatus'] ?? '').toString().trim();
      return deliveryStatus.isEmpty || deliveryStatus == 'pending_pickup';
    }).length;

    final onTheWay = driverRequests.where((request) {
      final deliveryStatus =
          (request['deliveryStatus'] ?? '').toString().trim();
      return deliveryStatus == 'picked_up' || deliveryStatus == 'on_the_way';
    }).length;

    final delivered = driverRequests.where((request) {
      final deliveryStatus =
          (request['deliveryStatus'] ?? '').toString().trim();
      final status = (request['status'] ?? '').toString().trim();
      return deliveryStatus == 'delivered' || status == 'delivered';
    }).length;

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
                      'لوحة السائق',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'استلام الطلبات وتتبع التوصيل للعميل',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
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
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جاهز للتوصيل',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'هذه الشاشة مخصصة للسائق الداخلي المسؤول عن استلام القطعة وتوصيلها للعميل.',
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
                        label: 'طلبات السائق',
                        value: driverRequests.length.toString(),
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'بانتظار الاستلام',
                        value: pendingPickup.toString(),
                        icon: Icons.store_mall_directory_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'في الطريق',
                        value: onTheWay.toString(),
                        icon: Icons.route_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
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
                        label: 'تم التسليم',
                        value: delivered.toString(),
                      ),
                      _SummaryRow(
                        label: 'الطلبات النشطة',
                        value: (driverRequests.length - delivered).toString(),
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

class _DriverAssignedOrdersTab extends StatelessWidget {
  const _DriverAssignedOrdersTab();

  bool _belongsToDriver(Map<String, dynamic> request, String currentUserId) {
    final assignedDriverId =
        (request['assignedDriverId'] ?? '').toString().trim();
    final driverId = (request['driverId'] ?? '').toString().trim();

    return assignedDriverId == currentUserId || driverId == currentUserId;
  }

  String _deliveryStatusText(Map<String, dynamic> request) {
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'pending_pickup':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      default:
        if (status == 'assigned') return 'جاهز للتكليف';
        if (status == 'shipped') return 'قيد التوصيل';
        if (status == 'delivered') return 'تم التسليم';
        return 'قيد المعالجة';
    }
  }

  Color _deliveryStatusColor(Map<String, dynamic> request) {
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'pending_pickup':
        return Colors.orange;
      case 'picked_up':
        return Colors.teal;
      case 'on_the_way':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        if (status == 'delivered') return Colors.green;
        if (status == 'assigned' || status == 'shipped') return Colors.orange;
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RequestProvider>();
    final currentUserId = auth.uid ?? '';

    final driverRequests = provider.requests
        .where((request) => _belongsToDriver(request, currentUserId))
        .toList();

    if (driverRequests.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لا توجد طلبات مسندة للسائق حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات السائق'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: driverRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = driverRequests[index];
          final partName = (request['partName'] ?? 'طلب بدون اسم').toString();
          final vehicle =
              '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}'
                  .trim();
          final deliveryAddress =
              (request['deliveryAddress'] ?? '').toString().trim();
          final customerPhone = (request['phone'] ?? '').toString().trim();
          final statusText = _deliveryStatusText(request);
          final statusColor = _deliveryStatusColor(request);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D21),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DriverInfoRow(
                  label: 'المركبة',
                  value: vehicle.isEmpty ? '-' : vehicle,
                ),
                _DriverInfoRow(
                  label: 'عنوان العميل',
                  value: deliveryAddress.isEmpty ? 'غير محدد' : deliveryAddress,
                ),
                _DriverInfoRow(
                  label: 'هاتف العميل',
                  value: customerPhone.isEmpty ? 'غير متوفر' : customerPhone,
                  isLast: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DriverProfileTab extends StatelessWidget {
  const _DriverProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب السائق'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D21),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.local_shipping_outlined, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  (user?.email ?? 'driver@tashlih.app').toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'دور الحساب: سائق',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: auth.isLoading
                ? null
                : () async {
                    await context.read<AuthProvider>().signOut();
                  },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ],
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

class _DriverInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DriverInfoRow({
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
