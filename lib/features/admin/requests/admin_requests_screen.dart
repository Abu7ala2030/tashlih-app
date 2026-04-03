import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/app_item_card.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip_filter.dart';
import '../../../providers/request_provider.dart';
import 'admin_request_offers_screen.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().listenToAllRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final allRequests = provider.requests;

    final requests = allRequests.where((request) {
      if (selectedStatus == 'all') return true;
      return (request['status'] ?? '') == selectedStatus;
    }).toList();

    final offersCount = allRequests
        .where((r) => (r['status'] ?? '').toString() == 'available')
        .length;

    final assignedCount = allRequests
        .where((r) => (r['status'] ?? '').toString() == 'assigned')
        .length;

    final commissionEligibleCount = allRequests
        .where((r) => (r['commissionEligible'] ?? false) == true)
        .length;

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
                        'إدارة الطلبات',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'تابع الطلبات القادمة من العملاء واعرض عروض العمال والعمولات المستحقة',
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
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'الكل',
                          value: allRequests.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'عروض',
                          value: offersCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'عمولات',
                          value: commissionEligibleCount.toString(),
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
                          label: 'جديد',
                          value: allRequests
                              .where((r) =>
                                  (r['status'] ?? '').toString() == 'newRequest')
                              .length
                              .toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'تم التعيين',
                          value: assignedCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'قيد التحقق',
                          value: allRequests
                              .where((r) =>
                                  (r['status'] ?? '').toString() ==
                                  'checkingAvailability')
                              .length
                              .toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      StatusChipFilter(
                        label: 'الكل',
                        selected: selectedStatus == 'all',
                        onTap: () => setState(() => selectedStatus = 'all'),
                      ),
                      StatusChipFilter(
                        label: 'جديد',
                        selected: selectedStatus == 'newRequest',
                        onTap: () => setState(() => selectedStatus = 'newRequest'),
                      ),
                      StatusChipFilter(
                        label: 'جاري التحقق',
                        selected: selectedStatus == 'checkingAvailability',
                        onTap: () => setState(
                          () => selectedStatus = 'checkingAvailability',
                        ),
                      ),
                      StatusChipFilter(
                        label: 'عروض',
                        selected: selectedStatus == 'available',
                        onTap: () => setState(() => selectedStatus = 'available'),
                      ),
                      StatusChipFilter(
                        label: 'تم التعيين',
                        selected: selectedStatus == 'assigned',
                        onTap: () => setState(() => selectedStatus = 'assigned'),
                      ),
                      StatusChipFilter(
                        label: 'غير متوفر',
                        selected: selectedStatus == 'unavailable',
                        onTap: () => setState(() => selectedStatus = 'unavailable'),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الطلبات',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${requests.length} طلب',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (requests.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.list_alt_outlined,
                        title: 'لا توجد طلبات ضمن هذه الحالة',
                        subtitle: 'ستظهر الطلبات هنا بمجرد أن يبدأ العملاء بإرسالها.',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final status = (request['status'] ?? '').toString();
                      final commissionEligible =
                          (request['commissionEligible'] ?? false) == true;

                      final rawCommissionBase =
                          request['commissionBaseAmount'] ?? 0;
                      final double commissionBaseAmount = rawCommissionBase is num
                          ? rawCommissionBase.toDouble()
                          : double.tryParse(rawCommissionBase.toString()) ?? 0.0;

                      final scrapyardName =
                          (request['scrapyardName'] ?? '').toString();
                      final city = (request['city'] ?? '-').toString();

                      return Column(
                        children: [
                          AppItemCard(
                            title: (request['partName'] ?? '').toString(),
                            subtitle:
                                '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\nالمدينة: $city${scrapyardName.isNotEmpty ? '\nالتشليح: $scrapyardName' : ''}',
                            imageUrl:
                                (request['vehicleCoverImage'] ?? '').toString(),
                            statusText: _statusText(status),
                            statusColor: _statusColor(status),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminRequestOffersScreen(request: request),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _BadgesRow(
                            status: status,
                            commissionEligible: commissionEligible,
                            commissionBaseAmount: commissionBaseAmount,
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'unavailable':
        return Colors.red;
      case 'checkingAvailability':
        return Colors.orange;
      case 'assigned':
        return Colors.teal;
      case 'newRequest':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'طلب جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'وصلت عروض';
      case 'unavailable':
        return 'غير متوفر';
      case 'assigned':
        return 'تم اختيار العرض';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }
}

class _BadgesRow extends StatelessWidget {
  final String status;
  final bool commissionEligible;
  final double commissionBaseAmount;

  const _BadgesRow({
    required this.status,
    required this.commissionEligible,
    required this.commissionBaseAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'available')
          const _InfoBadge(
            label: 'يوجد عروض',
            backgroundColor: Color(0xFF17301F),
            textColor: Colors.greenAccent,
          ),
        if (status == 'assigned')
          const _InfoBadge(
            label: 'تم تعيين عامل',
            backgroundColor: Color(0xFF15323A),
            textColor: Colors.cyanAccent,
          ),
        if (commissionEligible)
          _InfoBadge(
            label:
                'عمولة مستحقة على ${commissionBaseAmount.toStringAsFixed(2)} ريال',
            backgroundColor: const Color(0xFF33280F),
            textColor: Colors.amberAccent,
          )
        else if (status == 'assigned')
          const _InfoBadge(
            label: 'لا توجد عمولة لهذا الطلب',
            backgroundColor: Color(0xFF2B2B2B),
            textColor: Colors.white70,
          ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}