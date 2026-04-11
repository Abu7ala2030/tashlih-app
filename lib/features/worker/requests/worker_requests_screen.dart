import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
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

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().listenToWorkerRequests();
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
              onRetry: () => context.read<RequestProvider>().listenToWorkerRequests(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('customer_requests'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('worker_requests_subtitle'),
                        style: const TextStyle(
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
                          label: l10n.translate('all'),
                          value: allRequests.length.toString(),
                          icon: Icons.list_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('new'),
                          value: allRequests
                              .where((r) => (r['status'] ?? '') == 'newRequest')
                              .length
                              .toString(),
                          icon: Icons.fiber_new_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('assigned_short'),
                          value: allRequests
                              .where((r) => (r['status'] ?? '') == 'assigned')
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
                        label: l10n.translate('all'),
                        selected: selectedStatus == 'all',
                        onTap: () => setState(() => selectedStatus = 'all'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('new'),
                        selected: selectedStatus == 'newRequest',
                        onTap: () => setState(() => selectedStatus = 'newRequest'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('checking_availability'),
                        selected: selectedStatus == 'checkingAvailability',
                        onTap: () =>
                            setState(() => selectedStatus = 'checkingAvailability'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('offers'),
                        selected: selectedStatus == 'available',
                        onTap: () => setState(() => selectedStatus = 'available'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('assigned'),
                        selected: selectedStatus == 'assigned',
                        onTap: () => setState(() => selectedStatus = 'assigned'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('shipped'),
                        selected: selectedStatus == 'shipped',
                        onTap: () => setState(() => selectedStatus = 'shipped'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('delivered'),
                        selected: selectedStatus == 'delivered',
                        onTap: () => setState(() => selectedStatus = 'delivered'),
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
                      Expanded(
                        child: Text(
                          l10n.translate('requests'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${requests.length} ${l10n.translate('request_count_suffix')}',
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.assignment_outlined,
                        title: l10n.translate('no_requests_in_this_status'),
                        subtitle: l10n.translate('worker_requests_empty_subtitle'),
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
                            '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\n${l10n.translate('city')}: ${request['city'] ?? '-'}${_extraSubtitle(request)}',
                        imageUrl: (request['vehicleCoverImage'] ?? '').toString(),
                        statusText: _statusText(status),
                        statusColor: _statusColor(status),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkerRequestDetailsScreen(
                                request: request,
                              ),
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
    );
  }

  String _extraSubtitle(Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString();
    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      return '\n${l10n.translate('selected_price')}: ${(request['acceptedOfferPrice'] ?? '-').toString()} ${l10n.translate('sar')}';
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
        return l10n.translate('status_new_request');
      case 'checkingAvailability':
        return l10n.translate('status_checking');
      case 'available':
        return l10n.translate('status_offer_submitted');
      case 'unavailable':
        return l10n.translate('status_unavailable');
      case 'assigned':
        return l10n.translate('your_offer_selected');
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      default:
        return l10n.translate('unknown');
    }
  }
}