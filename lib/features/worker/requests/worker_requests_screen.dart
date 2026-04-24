import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/app_item_card.dart';
import '../../../core/widgets/app_shimmer_loader.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip_filter.dart';
import '../../../providers/request_provider.dart';
import 'worker_request_details_screen.dart';

class WorkerRequestsScreen extends StatefulWidget {
  const WorkerRequestsScreen({super.key});

  @override
  State<WorkerRequestsScreen> createState() => _WorkerRequestsScreenState();
}

class _WorkerRequestsScreenState extends State<WorkerRequestsScreen> {
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().listenToWorkerRequests(
            includeOpenRequests: true,
          );
    });
  }

  void _reload() {
    context.read<RequestProvider>().listenToWorkerRequests(
          includeOpenRequests: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final allRequests = provider.requests;

    final requests = allRequests.where((request) {
      if (selectedStatus == 'all') return true;
      return (request['status'] ?? '') == selectedStatus;
    }).toList();

    if (provider.isLoading) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(child: AppShimmerLoader()),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: AppErrorView(
              message: provider.errorMessage!,
              onRetry: _reload,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلبات العملاء',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'راجع الطلبات الجديدة المرتبطة بمركباتك وأكمل تتبع الطلبات التي تم اختيار عروضك فيها',
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
                            icon: Icons.list_alt_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'جديد',
                            value: allRequests
                                .where(
                                  (r) =>
                                      (r['status'] ?? '') == 'newRequest',
                                )
                                .length
                                .toString(),
                            icon: Icons.fiber_new_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'معينة',
                            value: allRequests
                                .where(
                                  (r) => (r['status'] ?? '') == 'assigned',
                                )
                                .length
                                .toString(),
                            icon: Icons.verified_outlined,
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
                          onTap: () =>
                              setState(() => selectedStatus = 'newRequest'),
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
                          onTap: () =>
                              setState(() => selectedStatus = 'available'),
                        ),
                        StatusChipFilter(
                          label: 'تم التعيين',
                          selected: selectedStatus == 'assigned',
                          onTap: () =>
                              setState(() => selectedStatus = 'assigned'),
                        ),
                        StatusChipFilter(
                          label: 'تم الشحن',
                          selected: selectedStatus == 'shipped',
                          onTap: () =>
                              setState(() => selectedStatus = 'shipped'),
                        ),
                        StatusChipFilter(
                          label: 'تم التسليم',
                          selected: selectedStatus == 'delivered',
                          onTap: () =>
                              setState(() => selectedStatus = 'delivered'),
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
                          icon: Icons.assignment_outlined,
                          title: 'لا توجد طلبات ضمن هذه الحالة',
                          subtitle:
                              'بمجرد وصول طلبات جديدة على مركباتك ستظهر هنا لتقوم بمراجعتها أو متابعتها.',
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

                        return AppItemCard(
                          title: (request['partName'] ?? '').toString(),
                          subtitle:
                              '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\n'
                              'المدينة: ${request['city'] ?? '-'}'
                              '${_extraSubtitle(request)}',
                          imageUrl:
                              (request['vehicleCoverImage'] ?? '').toString(),
                          statusText: _statusText(status),
                          statusColor: _statusColor(status),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    WorkerRequestDetailsScreen(request: request),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extraSubtitle(Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString();
    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      return '\nالسعر المختار: ${(request['acceptedOfferPrice'] ?? '-').toString()} ريال';
    }
    return '';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'unavailable':
        return Colors.red;
      case 'checkingAvailability':
        return Colors.orange;
      case 'newRequest':
        return Colors.blue;
      case 'assigned':
        return Colors.teal;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.greenAccent;
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
        return 'تم تقديم عرض';
      case 'unavailable':
        return 'غير متوفر';
      case 'assigned':
        return 'تم اختيار عرضك';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'غير معروف';
    }
  }
}