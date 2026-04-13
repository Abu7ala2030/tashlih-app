import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
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

  AppLocalizations get l10n => AppLocalizations.of(context);

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('requests_management'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('requests_management_subtitle'),
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('offers'),
                          value: offersCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('commissions'),
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
                          label: l10n.translate('new'),
                          value: allRequests
                              .where((r) => (r['status'] ?? '').toString() == 'newRequest')
                              .length
                              .toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('assigned'),
                          value: assignedCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('checking_availability'),
                          value: allRequests
                              .where((r) =>
                                  (r['status'] ?? '').toString() == 'checkingAvailability')
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
                        onTap: () => setState(() => selectedStatus = 'checkingAvailability'),
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
                        label: l10n.translate('status_unavailable'),
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
                        icon: Icons.list_alt_outlined,
                        title: l10n.translate('no_requests_in_this_status'),
                        subtitle: l10n.translate('admin_requests_empty_subtitle'),
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
                                '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\n${l10n.translate('city')}: $city${scrapyardName.isNotEmpty ? '\n${l10n.translate('scrapyard')}: $scrapyardName' : ''}',
                            imageUrl:
                                (request['vehicleCoverImage'] ?? '').toString(),
                            statusText: _statusText(status),
                            statusColor: _statusColor(status),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminRequestOffersScreen(request: request),
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
        return l10n.translate('status_new_request');
      case 'checkingAvailability':
        return l10n.translate('status_checking');
      case 'available':
        return l10n.translate('status_offer_submitted');
      case 'unavailable':
        return l10n.translate('status_unavailable');
      case 'assigned':
        return l10n.translate('status_offer_selected');
      case 'cancelled':
        return l10n.translate('status_cancelled');
      default:
        return l10n.translate('unknown');
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
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'available')
          _InfoBadge(
            label: l10n.translate('offers_exist'),
            backgroundColor: const Color(0xFF17301F),
            textColor: Colors.greenAccent,
          ),
        if (status == 'assigned')
          _InfoBadge(
            label: l10n.translate('worker_assigned'),
            backgroundColor: const Color(0xFF15323A),
            textColor: Colors.cyanAccent,
          ),
        if (commissionEligible)
          _InfoBadge(
            label:
                '${l10n.translate('commission_due_on')} ${commissionBaseAmount.toStringAsFixed(2)} ${l10n.translate('sar')}',
            backgroundColor: const Color(0xFF33280F),
            textColor: Colors.amberAccent,
          )
        else if (status == 'assigned')
          _InfoBadge(
            label: l10n.translate('no_commission_for_this_request'),
            backgroundColor: const Color(0xFF2B2B2B),
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