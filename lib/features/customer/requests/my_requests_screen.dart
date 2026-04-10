import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../shared/notifications/notification_bell_button.dart';
import 'customer_request_offers_screen.dart';
import 'customer_request_tracking_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestProvider>().listenToMyRequests();
    });
  }

  @override
  void dispose() {
    context.read<RequestProvider>().stopListening();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<RequestProvider>().listenToMyRequests();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  List<Map<String, dynamic>> _sortRequests(List<Map<String, dynamic>> input) {
    final requests = [...input];

    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    requests.sort((a, b) {
      final aNewOffers = ((a['newOffersCount'] ?? 0) as num).toInt();
      final bNewOffers = ((b['newOffersCount'] ?? 0) as num).toInt();

      final aHasNewOffers = aNewOffers > 0;
      final bHasNewOffers = bNewOffers > 0;

      if (aHasNewOffers != bHasNewOffers) {
        return aHasNewOffers ? -1 : 1;
      }

      if (aHasNewOffers && bHasNewOffers && aNewOffers != bNewOffers) {
        return bNewOffers.compareTo(aNewOffers);
      }

      final aLastOfferAt = readDate(a['lastOfferAt']);
      final bLastOfferAt = readDate(b['lastOfferAt']);

      if (aHasNewOffers && bHasNewOffers && aLastOfferAt != bLastOfferAt) {
        return bLastOfferAt.compareTo(aLastOfferAt);
      }

      final aCreatedAt = readDate(a['createdAt']);
      final bCreatedAt = readDate(b['createdAt']);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return requests;
  }

  bool _matchesSelectedStatus(Map<String, dynamic> request) {
    if (selectedStatus == 'all') return true;
    if (selectedStatus == 'newOffersOnly') {
      return ((request['newOffersCount'] ?? 0) as num).toInt() > 0;
    }
    return (request['status'] ?? '') == selectedStatus;
  }

  void _openRequest(BuildContext context, Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString();

    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerRequestTrackingScreen(request: request),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerRequestOffersScreen(request: request),
      ),
    );
  }

  void _openFirstRequestWithNewOffers(
    BuildContext context,
    List<Map<String, dynamic>> sortedRequests,
  ) {
    final l10n = AppLocalizations.of(context);

    final target = sortedRequests.where((request) {
      return ((request['newOffersCount'] ?? 0) as num).toInt() > 0;
    }).toList();

    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('no_requests_with_new_offers_now')),
        ),
      );
      return;
    }

    _openRequest(context, target.first);
  }

  double _bestOfferValue(Map<String, dynamic> request) {
    final raw = request['bestOfferPrice'];
    if (raw is num) return raw.toDouble();
    return 0;
  }

  void _openHighestOfferRequest(
    BuildContext context,
    List<Map<String, dynamic>> allRequests,
  ) {
    final l10n = AppLocalizations.of(context);

    final candidates = allRequests.where((request) {
      return _bestOfferValue(request) > 0;
    }).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('no_saved_highest_offer_now')),
        ),
      );
      return;
    }

    candidates.sort((a, b) {
      final priceCompare = _bestOfferValue(b).compareTo(_bestOfferValue(a));
      if (priceCompare != 0) return priceCompare;

      final aNewOffers = ((a['newOffersCount'] ?? 0) as num).toInt();
      final bNewOffers = ((b['newOffersCount'] ?? 0) as num).toInt();
      return bNewOffers.compareTo(aNewOffers);
    });

    _openRequest(context, candidates.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RequestProvider>();
    final allRequests = _sortRequests(provider.requests);

    final requests = _sortRequests(
      allRequests.where(_matchesSelectedStatus).toList(),
    );

    final newOffersRequestsCount = allRequests.where((r) {
      return ((r['newOffersCount'] ?? 0) as num).toInt() > 0;
    }).length;

    final highestOfferCount = allRequests.where((r) {
      return _bestOfferValue(r) > 0;
    }).length;

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
              onRetry: () => context.read<RequestProvider>().listenToMyRequests(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('my_requests'),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.translate('my_requests_subtitle'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const NotificationBellButton(),
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
                            label: l10n.translate('new'),
                            value: allRequests
                                .where((r) => (r['status'] ?? '') == 'newRequest')
                                .length
                                .toString(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: l10n.translate('new_offers'),
                            value: newOffersRequestsCount.toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final created = await Navigator.pushNamed(
                            context,
                            '/part-request',
                          );

                          if (created == true && mounted) {
                            context.read<RequestProvider>().listenToMyRequests();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('request_created_follow_here'),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(l10n.translate('new_request')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (newOffersRequestsCount > 0 || highestOfferCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2216),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedStatus == 'newOffersOnly'
                                    ? l10n.translate('showing_new_offers_only')
                                    : l10n.translate('quick_buttons_help'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: newOffersRequestsCount > 0
                                ? () => _openFirstRequestWithNewOffers(
                                      context,
                                      allRequests,
                                    )
                                : null,
                            icon: const Icon(Icons.flash_on_outlined),
                            label: Text(
                              newOffersRequestsCount > 0
                                  ? l10n.translate('open_first_request_with_new_offers')
                                  : l10n.translate('no_requests_with_new_offers'),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: highestOfferCount > 0
                                ? () => _openHighestOfferRequest(
                                      context,
                                      allRequests,
                                    )
                                : null,
                            icon: const Icon(Icons.trending_up),
                            label: Text(
                              highestOfferCount > 0
                                  ? l10n.translate('open_highest_offer')
                                  : l10n.translate('no_saved_offer'),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
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
                          label: l10n.translate('new_offers_only'),
                          selected: selectedStatus == 'newOffersOnly',
                          onTap: () =>
                              setState(() => selectedStatus = 'newOffersOnly'),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('new'),
                          selected: selectedStatus == 'newRequest',
                          onTap: () =>
                              setState(() => selectedStatus = 'newRequest'),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('checking_availability'),
                          selected: selectedStatus == 'checkingAvailability',
                          onTap: () => setState(
                            () => selectedStatus = 'checkingAvailability',
                          ),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('offers'),
                          selected: selectedStatus == 'available',
                          onTap: () =>
                              setState(() => selectedStatus = 'available'),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('assigned'),
                          selected: selectedStatus == 'assigned',
                          onTap: () =>
                              setState(() => selectedStatus = 'assigned'),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('shipped'),
                          selected: selectedStatus == 'shipped',
                          onTap: () =>
                              setState(() => selectedStatus = 'shipped'),
                        ),
                        StatusChipFilter(
                          label: l10n.translate('delivered'),
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
                          icon: selectedStatus == 'newOffersOnly'
                              ? Icons.local_offer_outlined
                              : Icons.inventory_2_outlined,
                          title: selectedStatus == 'newOffersOnly'
                              ? l10n.translate('no_requests_with_new_offers')
                              : l10n.translate('no_requests_in_this_status'),
                          subtitle: selectedStatus == 'newOffersOnly'
                              ? l10n.translate('new_offer_will_appear_here')
                              : l10n.translate('new_request_will_appear_here'),
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
                        final newOffersCount =
                            ((request['newOffersCount'] ?? 0) as num).toInt();

                        return Stack(
                          children: [
                            AppItemCard(
                              title: (request['partName'] ?? '').toString(),
                              subtitle:
                                  '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\n${l10n.translate('city')}: ${request['city'] ?? '-'}${_extraSubtitle(request, l10n)}',
                              imageUrl:
                                  (request['vehicleCoverImage'] ?? '').toString(),
                              statusText: _statusText(status, l10n),
                              statusColor: _statusColor(status),
                              onTap: () => _openRequest(context, request),
                            ),
                            if (newOffersCount > 0)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    newOffersCount == 1
                                        ? l10n.translate('one_new_offer')
                                        : '${newOffersCount} ${l10n.translate('multiple_new_offers')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            if (_bestOfferValue(request) > 0)
                              Positioned(
                                bottom: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF123B2E),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${l10n.translate('highest_offer')}: ${_bestOfferValue(request).toStringAsFixed(0)} ${l10n.translate('sar')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
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
      ),
    );
  }

  String _extraSubtitle(
    Map<String, dynamic> request,
    AppLocalizations l10n,
  ) {
    final status = (request['status'] ?? '').toString();
    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      final rawPrice = request['acceptedOfferPrice'] ?? 0;
      final displayPrice = rawPrice.toString();
      return '\n${l10n.translate('selected_price')}: $displayPrice ${l10n.translate('sar')}';
    }

    final bestOffer = _bestOfferValue(request);
    final newOffersCount = ((request['newOffersCount'] ?? 0) as num).toInt();

    final lines = <String>[];
    if (newOffersCount > 0) {
      lines.add(
        '${l10n.translate('you_have')} $newOffersCount ${l10n.translate('new_offers_on_request')}',
      );
    }
    if (bestOffer > 0) {
      lines.add(
        '${l10n.translate('current_highest_offer')}: ${bestOffer.toStringAsFixed(0)} ${l10n.translate('sar')}',
      );
    }

    if (lines.isEmpty) return '';
    return '\n${lines.join(' • ')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'unavailable':
        return Colors.red;
      case 'checkingAvailability':
        return Colors.orange;
      case 'reserved':
        return Colors.purple;
      case 'confirmed':
        return Colors.teal;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.greenAccent;
      case 'assigned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'newRequest':
        return l10n.translate('status_new_request');
      case 'checkingAvailability':
        return l10n.translate('status_checking');
      case 'available':
        return l10n.translate('status_offers_arrived');
      case 'unavailable':
        return l10n.translate('status_unavailable');
      case 'reserved':
        return l10n.translate('status_reserved');
      case 'confirmed':
        return l10n.translate('status_confirmed');
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      case 'cancelled':
        return l10n.translate('status_cancelled');
      case 'assigned':
        return l10n.translate('status_offer_selected');
      default:
        return l10n.translate('unknown');
    }
  }
}