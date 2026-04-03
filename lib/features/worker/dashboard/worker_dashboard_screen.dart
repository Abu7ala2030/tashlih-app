import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';

class WorkerDashboardScreen extends StatelessWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();

    final allVehicles = vehicleProvider.vehicles;
    final pendingVehicles = allVehicles.where((v) => (v['status'] ?? '') == 'pending').toList();
    final publishedVehicles = allVehicles.where((v) => (v['status'] ?? '') == 'published').toList();

    final allRequests = requestProvider.requests;
    final newRequests = allRequests.where((r) => (r['status'] ?? '') == 'newRequest').toList();
    final checkingRequests = allRequests.where((r) => (r['status'] ?? '') == 'checkingAvailability').toList();
    final availableRequests = allRequests.where((r) => (r['status'] ?? '') == 'available').toList();

    return Scaffold(
      body: AppGradientBackground(
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
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'أضف المركبات الجديدة وتابع طلبات العملاء بسرعة',
                              style: TextStyle(color: Colors.white70, height: 1.5),
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
                        BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('جاهز للعمل', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        Text(
                          'كل مركبة تضيفها بشكل واضح تزيد فرص حصولك على طلبات أكثر.',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.4),
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
                      Expanded(child: StatCard(label: 'كل المركبات', value: allVehicles.length.toString(), icon: Icons.directions_car_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'قيد المراجعة', value: pendingVehicles.length.toString(), icon: Icons.hourglass_top_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'منشورة', value: publishedVehicles.length.toString(), icon: Icons.verified_outlined)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: StatCard(label: 'طلبات جديدة', value: newRequests.length.toString(), icon: Icons.fiber_new_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'جاري التحقق', value: checkingRequests.length.toString(), icon: Icons.search_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'متوفرة', value: availableRequests.length.toString(), icon: Icons.check_circle_outline)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: const Text('إجراءات سريعة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    children: const [
                      _QuickActionTile(
                        icon: Icons.add_box_outlined,
                        title: 'إضافة مركبة جديدة',
                        subtitle: 'ارفع صور السيارة وأدخل معلوماتها بسرعة',
                        color: Color(0xFF1D3557),
                      ),
                      SizedBox(height: 12),
                      _QuickActionTile(
                        icon: Icons.assignment_outlined,
                        title: 'متابعة الطلبات',
                        subtitle: 'راجع الطلبات الجديدة وحدد حالة التوفر',
                        color: Color(0xFF264653),
                      ),
                      SizedBox(height: 12),
                      _QuickActionTile(
                        icon: Icons.photo_library_outlined,
                        title: 'تحسين جودة الصور',
                        subtitle: 'كلما كانت الصور أوضح زادت احتمالية الطلب',
                        color: Color(0xFF3A2E39),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: const Text('ملخص سريع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
                        _SummaryRow(label: 'المركبات المضافة', value: allVehicles.length.toString()),
                        _SummaryRow(label: 'المركبات بانتظار الاعتماد', value: pendingVehicles.length.toString()),
                        _SummaryRow(label: 'الطلبات الجديدة', value: newRequests.length.toString()),
                        _SummaryRow(label: 'الطلبات المتوفرة', value: availableRequests.length.toString(), isLast: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.28),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.45)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
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
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(.08))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}
