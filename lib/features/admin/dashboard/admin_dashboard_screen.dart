import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../finance/admin_commissions_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController commissionPercentController =
      TextEditingController(text: '10');

  @override
  void dispose() {
    commissionPercentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();

    final allVehicles = vehicleProvider.vehicles;
    final pendingVehicles =
        allVehicles.where((v) => (v['status'] ?? '') == 'pending').toList();
    final publishedVehicles =
        allVehicles.where((v) => (v['status'] ?? '') == 'published').toList();
    final rejectedVehicles =
        allVehicles.where((v) => (v['status'] ?? '') == 'rejected').toList();

    final allRequests = requestProvider.requests;
    final newRequests =
        allRequests.where((r) => (r['status'] ?? '') == 'newRequest').toList();
    final availableRequests =
        allRequests.where((r) => (r['status'] ?? '') == 'available').toList();
    final assignedRequests =
        allRequests.where((r) => (r['status'] ?? '') == 'assigned').toList();
    final checkingRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'checkingAvailability')
        .toList();

    final commissionEligibleRequests = assignedRequests
        .where((r) => (r['commissionEligible'] ?? false) == true)
        .toList();

    final commissionPercent =
        double.tryParse(commissionPercentController.text.trim()) ?? 0;

    double totalCommissionBase = 0;
    for (final request in commissionEligibleRequests) {
      final raw = request['commissionBaseAmount'] ?? 0;
      final amount =
          raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
      totalCommissionBase += amount;
    }

    final estimatedCommission =
        totalCommissionBase * commissionPercent / 100;

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
                              'لوحة الإدارة',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'راقب المركبات والطلبات والعمولات من مكان واحد',
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
                        colors: [Color(0xFF2B1D2F), Color(0xFF1A1D21)],
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
                          'ملخص الإدارة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'تابع ما يحتاج مراجعة الآن وراقب المبيعات المؤهلة للعمولة.',
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
                          icon: Icons.public_outlined,
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
                          label: 'عروض',
                          value: availableRequests.length.toString(),
                          icon: Icons.local_offer_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'تم التعيين',
                          value: assignedRequests.length.toString(),
                          icon: Icons.verified_outlined,
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
                    'ملخص العمولات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'نسبة العمولة %',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: commissionPercentController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  hintText: '10',
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
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SummaryRow(
                          label: 'طلبات مؤهلة للعمولة',
                          value: commissionEligibleRequests.length.toString(),
                        ),
                        _SummaryRow(
                          label: 'إجمالي قيمة البيع المؤهل',
                          value:
                              '${totalCommissionBase.toStringAsFixed(2)} ريال',
                        ),
                        _SummaryRow(
                          label: 'العمولة التقديرية',
                          value:
                              '${estimatedCommission.toStringAsFixed(2)} ريال',
                          isHighlighted: true,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'إجراءات سريعة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    children: [
                      const _QuickActionTile(
                        icon: Icons.fact_check_outlined,
                        title: 'مراجعة المركبات',
                        subtitle: 'اعتماد أو رفض المركبات المرفوعة من العمال',
                        color: Color(0xFF2C2A4A),
                      ),
                      const SizedBox(height: 12),
                      const _QuickActionTile(
                        icon: Icons.list_alt_outlined,
                        title: 'إدارة الطلبات',
                        subtitle: 'راجع الطلبات والعروض وتتبع العمولات',
                        color: Color(0xFF1E3A3A),
                      ),
                      const SizedBox(height: 12),
                      _QuickActionTile(
                        icon: Icons.paid_outlined,
                        title: 'لوحة العمولات',
                        subtitle: 'مراجعة العمولات الفعلية وتصدير CSV',
                        color: const Color(0xFF3A2E39),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminCommissionsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'ملخص الإدارة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
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
                          label: 'المركبات المرفوضة',
                          value: rejectedVehicles.length.toString(),
                        ),
                        _SummaryRow(
                          label: 'طلبات قيد التحقق',
                          value: checkingRequests.length.toString(),
                        ),
                        _SummaryRow(
                          label: 'الطلبات التي فيها عروض',
                          value: availableRequests.length.toString(),
                        ),
                        _SummaryRow(
                          label: 'الطلبات المعينة',
                          value: assignedRequests.length.toString(),
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
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
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
  final bool isHighlighted;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(.08),
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isHighlighted ? Colors.amberAccent : Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isHighlighted ? Colors.amberAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
