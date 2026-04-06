import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';
import '../requests/driver_request_details_screen.dart';

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

  bool _isActiveDelivery(Map<String, dynamic> request) {
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    if (deliveryStatus == 'delivered' || status == 'delivered') return false;
    return true;
  }

  String _statusText(Map<String, dynamic> request) {
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return 'بانتظار بدء التنفيذ';
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

  Color _statusColor(Map<String, dynamic> request) {
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
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

    driverRequests.sort((a, b) {
      final aTime = a['updatedAt'];
      final bTime = b['updatedAt'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    final pendingPickup = driverRequests.where((request) {
      final deliveryStatus =
          (request['deliveryStatus'] ?? '').toString().trim();
      return deliveryStatus == 'pending_pickup' ||
          deliveryStatus == 'awaiting_driver_assignment';
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

    Map<String, dynamic>? activeRequest;
    for (final request in driverRequests) {
      if (_isActiveDelivery(request)) {
        activeRequest = request;
        break;
      }
    }

    return AppGradientBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const Text(
              'لوحة السائق',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تابع الطلب الحالي، حالة التوصيل، وابدأ التحرك المباشر بشكل احترافي.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: currentUserId.isEmpty
                  ? null
                  : FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(currentUserId)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final isOnline = data['isOnline'] == true;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: isOnline
                          ? const [Color(0xFF173C2B), Color(0xFF10251B)]
                          : const [Color(0xFF35211B), Color(0xFF221512)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'أنت الآن متصل' : 'أنت الآن غير متصل',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isOnline
                                  ? 'سيتم عرض موقعك للعميل أثناء التوصيل.'
                                  : 'فعّل الاتصال لتجهيز التتبع المباشر.',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'الطلبات',
                    value: driverRequests.length.toString(),
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'بانتظار الاستلام',
                    value: pendingPickup.toString(),
                    icon: Icons.store_mall_directory_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'في الطريق',
                    value: onTheWay.toString(),
                    icon: Icons.route_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D21),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'تم التسليم', value: delivered.toString()),
                  _SummaryRow(
                    label: 'الطلبات النشطة',
                    value: (driverRequests.length - delivered).toString(),
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (activeRequest != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الطلب الحالي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (activeRequest['partName'] ?? 'طلب بدون اسم')
                                .toString(),
                            style: const TextStyle(
                              fontSize: 20,
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
                            color: _statusColor(activeRequest).withOpacity(.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusText(activeRequest),
                            style: TextStyle(
                              color: _statusColor(activeRequest),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DriverInfoRow(
                      label: 'المركبة',
                      value:
                          '${activeRequest['vehicleMake'] ?? ''} ${activeRequest['vehicleModel'] ?? ''} ${activeRequest['vehicleYear'] ?? ''}'
                                  .trim()
                                  .isEmpty
                              ? '-'
                              : '${activeRequest['vehicleMake'] ?? ''} ${activeRequest['vehicleModel'] ?? ''} ${activeRequest['vehicleYear'] ?? ''}'
                                  .trim(),
                    ),
                    _DriverInfoRow(
                      label: 'العنوان',
                      value: (activeRequest['deliveryAddress'] ?? '')
                              .toString()
                              .trim()
                              .isEmpty
                          ? 'غير محدد'
                          : (activeRequest['deliveryAddress'] ?? '')
                              .toString()
                              .trim(),
                    ),
                    _DriverInfoRow(
                      label: 'الهاتف',
                      value: (activeRequest['phone'] ?? '')
                              .toString()
                              .trim()
                              .isEmpty
                          ? 'غير متوفر'
                          : (activeRequest['phone'] ?? '').toString().trim(),
                      isLast: true,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverRequestDetailsScreen(
                                request: activeRequest!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.playlist_add_check_circle_outlined),
                        label: const Text('فتح تفاصيل الطلب الحالي'),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 42,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'لا يوجد طلب نشط حاليًا',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'عند إسناد طلب جديد لك سيظهر هنا مباشرة مع الإجراءات السريعة.',
                      textAlign: TextAlign.center,
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
    );
  }
}

class _DriverAssignedOrdersTab extends StatefulWidget {
  const _DriverAssignedOrdersTab();

  @override
  State<_DriverAssignedOrdersTab> createState() => _DriverAssignedOrdersTabState();
}

class _DriverAssignedOrdersTabState extends State<_DriverAssignedOrdersTab> {
  String filter = 'all';

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
      case 'awaiting_driver_assignment':
        return 'بانتظار بدء التنفيذ';
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
      case 'awaiting_driver_assignment':
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

  bool _matchesFilter(Map<String, dynamic> request) {
    if (filter == 'all') return true;

    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    switch (filter) {
      case 'pickup':
        return deliveryStatus == 'awaiting_driver_assignment' ||
            deliveryStatus == 'pending_pickup' ||
            status == 'assigned';
      case 'moving':
        return deliveryStatus == 'picked_up' ||
            deliveryStatus == 'on_the_way' ||
            status == 'shipped';
      case 'done':
        return deliveryStatus == 'delivered' || status == 'delivered';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RequestProvider>();
    final currentUserId = auth.uid ?? '';

    final driverRequests = provider.requests
        .where((request) => _belongsToDriver(request, currentUserId))
        .where(_matchesFilter)
        .toList();

    driverRequests.sort((a, b) {
      final aTime = a['updatedAt'];
      final bTime = b['updatedAt'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات السائق'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: filter == 'all',
                  onTap: () => setState(() => filter = 'all'),
                ),
                _FilterChip(
                  label: 'الاستلام',
                  selected: filter == 'pickup',
                  onTap: () => setState(() => filter = 'pickup'),
                ),
                _FilterChip(
                  label: 'في الحركة',
                  selected: filter == 'moving',
                  onTap: () => setState(() => filter = 'moving'),
                ),
                _FilterChip(
                  label: 'المكتملة',
                  selected: filter == 'done',
                  onTap: () => setState(() => filter = 'done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: driverRequests.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد طلبات مطابقة لهذا التصنيف حاليًا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: driverRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = driverRequests[index];
                      final partName =
                          (request['partName'] ?? 'طلب بدون اسم').toString();
                      final vehicle =
                          '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}'
                              .trim();
                      final deliveryAddress =
                          (request['deliveryAddress'] ?? '').toString().trim();
                      final customerPhone =
                          (request['phone'] ?? '').toString().trim();
                      final statusText = _deliveryStatusText(request);
                      final statusColor = _deliveryStatusColor(request);

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverRequestDetailsScreen(
                                request: request,
                              ),
                            ),
                          );
                        },
                        child: Container(
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
                                value: deliveryAddress.isEmpty
                                    ? 'غير محدد'
                                    : deliveryAddress,
                              ),
                              _DriverInfoRow(
                                label: 'هاتف العميل',
                                value: customerPhone.isEmpty
                                    ? 'غير متوفر'
                                    : customerPhone,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileTab extends StatelessWidget {
  const _DriverProfileTab();

  Future<void> _toggleAvailability(
    BuildContext context, {
    required String uid,
    required bool nextValue,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isActive': nextValue,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
      'isOnline': nextValue,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final uid = auth.uid ?? '';

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
          if (uid.isNotEmpty)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final isOnline = data['isOnline'] == true;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حالة السائق',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOnline ? 'متصل وجاهز للتوصيل' : 'غير متصل',
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isOnline,
                        onChanged: (value) {
                          _toggleAvailability(
                            context,
                            uid: uid,
                            nextValue: value,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
