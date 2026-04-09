import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../finance/admin_commissions_screen.dart';
import '../requests/admin_request_offers_screen.dart';
import '../review/review_vehicle_screen.dart';
import '../workers/manage_workers_screen.dart';
import 'models/admin_dashboard_stats.dart';
import 'models/admin_recent_request.dart';
import 'services/admin_dashboard_service.dart';
import 'widgets/admin_metric_card.dart';
import 'widgets/admin_recent_request_tile.dart';
import 'widgets/admin_worker_summary_tile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final pages = [
      const _AdminOverviewTab(),
      const _AdminRequestsTab(),
      const ManageWorkersScreen(),
      const AdminCommissionsScreen(),
      const ReviewVehicleScreen(),
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.translate('nav_requests'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.translate('nav_workers'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.translate('nav_finance'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check),
            label: l10n.translate('nav_review'),
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewTab extends StatefulWidget {
  const _AdminOverviewTab();

  @override
  State<_AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<_AdminOverviewTab> {
  final AdminDashboardService _service = AdminDashboardService();
  late Future<AdminDashboardBundle> _future;
  AdminDashboardRange _selectedRange = AdminDashboardRange.all;

  @override
  void initState() {
    super.initState();
    _future = _service.loadDashboardData(range: _selectedRange);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.loadDashboardData(range: _selectedRange);
    });
    await _future;
  }

  void _changeRange(AdminDashboardRange range) {
    setState(() {
      _selectedRange = range;
      _future = _service.loadDashboardData(range: _selectedRange);
    });
  }

  String _rangeLabel(
    BuildContext context,
    AdminDashboardRange range,
  ) {
    final l10n = AppLocalizations.of(context);

    switch (range) {
      case AdminDashboardRange.today:
        return l10n.translate('range_today');
      case AdminDashboardRange.week:
        return l10n.translate('range_week');
      case AdminDashboardRange.month:
        return l10n.translate('range_month');
      case AdminDashboardRange.all:
        return l10n.translate('range_all');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();

    return AppGradientBackground(
      child: SafeArea(
        child: FutureBuilder<AdminDashboardBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${l10n.translate('load_dashboard_failed')}\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final bundle = snapshot.data ??
                AdminDashboardBundle(
                  stats: AdminDashboardStats.empty(),
                  recentRequests: [],
                  topWorkers: [],
                );

            final stats = bundle.stats;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate('admin_dashboard'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            localeProvider.toggleLocale();
                          },
                          icon: const Icon(Icons.language),
                          label: Text(
                            localeProvider.isArabic ? 'EN' : 'AR',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.translate('dashboard_overview')} • ${l10n.translate('period')}: ${_rangeLabel(context, _selectedRange)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _RangeChip(
                        label: l10n.translate('range_today'),
                        selected: _selectedRange == AdminDashboardRange.today,
                        onTap: () => _changeRange(AdminDashboardRange.today),
                      ),
                      _RangeChip(
                        label: l10n.translate('range_week'),
                        selected: _selectedRange == AdminDashboardRange.week,
                        onTap: () => _changeRange(AdminDashboardRange.week),
                      ),
                      _RangeChip(
                        label: l10n.translate('range_month'),
                        selected: _selectedRange == AdminDashboardRange.month,
                        onTap: () => _changeRange(AdminDashboardRange.month),
                      ),
                      _RangeChip(
                        label: l10n.translate('range_all'),
                        selected: _selectedRange == AdminDashboardRange.all,
                        onTap: () => _changeRange(AdminDashboardRange.all),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('executive_summary'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.translate('total_requests')} ${stats.totalRequests} • ${l10n.translate('revenues')} ${stats.totalRevenue.toStringAsFixed(2)} ${l10n.translate('sar')} • ${l10n.translate('commissions')} ${stats.totalCommission.toStringAsFixed(2)} ${l10n.translate('sar')}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      AdminMetricCard(
                        label: l10n.translate('total_requests'),
                        value: stats.totalRequests.toString(),
                        icon: Icons.assignment_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('new_requests'),
                        value: stats.newRequests.toString(),
                        icon: Icons.fiber_new_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('active_requests'),
                        value: stats.activeRequests.toString(),
                        icon: Icons.timelapse_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('completed_requests'),
                        value: stats.completedRequests.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('cancelled_requests'),
                        value: stats.cancelledRequests.toString(),
                        icon: Icons.cancel_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('late_requests'),
                        value: stats.lateRequests.toString(),
                        icon: Icons.warning_amber_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('today_revenue'),
                        value:
                            '${stats.todayRevenue.toStringAsFixed(0)} ${l10n.translate('sar')}',
                        icon: Icons.today_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('week_revenue'),
                        value:
                            '${stats.weekRevenue.toStringAsFixed(0)} ${l10n.translate('sar')}',
                        icon: Icons.date_range_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('month_revenue'),
                        value:
                            '${stats.monthRevenue.toStringAsFixed(0)} ${l10n.translate('sar')}',
                        icon: Icons.calendar_month_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('total_commission'),
                        value:
                            '${stats.totalCommission.toStringAsFixed(0)} ${l10n.translate('sar')}',
                        icon: Icons.payments_outlined,
                      ),
                      AdminMetricCard(
                        label: l10n.translate('workers_count'),
                        value: stats.totalWorkers.toString(),
                        icon: Icons.groups_2_outlined,
                        subtitle:
                            '${l10n.translate('online_count')}: ${stats.onlineWorkers}',
                      ),
                      AdminMetricCard(
                        label: l10n.translate('drivers_count'),
                        value: stats.totalDrivers.toString(),
                        icon: Icons.local_shipping_outlined,
                        subtitle:
                            '${l10n.translate('online_count')}: ${stats.onlineDrivers}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: l10n.translate('latest_requests'),
                    subtitle: l10n.translate('latest_10_requests'),
                  ),
                  const SizedBox(height: 12),
                  if (bundle.recentRequests.isEmpty)
                    _EmptyCard(
                      text: l10n.translate('no_recent_requests'),
                    )
                  else
                    ...bundle.recentRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminRecentRequestTile(request: request),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: l10n.translate('top_workers'),
                    subtitle: l10n.translate('top_workers_subtitle'),
                  ),
                  const SizedBox(height: 12),
                  if (bundle.topWorkers.isEmpty)
                    _EmptyCard(
                      text: l10n.translate('no_workers_data'),
                    )
                  else
                    ...bundle.topWorkers.map(
                      (worker) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminWorkerSummaryTile(worker: worker),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminRequestsTab extends StatelessWidget {
  const _AdminRequestsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppGradientBackground(
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(FirestorePaths.requests)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${l10n.translate('load_requests_failed')}\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  l10n.translate('no_requests_now'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: docs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('requests_monitoring'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.translate('requests_monitoring_subtitle'),
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final doc = docs[index - 1];
                final request = {
                  'id': doc.id,
                  ...doc.data(),
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminRecentRequestTile(
                    request: _requestFromMap(request),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminRequestOffersScreen(
                            request: request,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  AdminRecentRequest _requestFromMap(Map<String, dynamic> data) {
    return AdminRecentRequest(
      id: (data['id'] ?? '').toString(),
      partName: (data['partName'] ?? 'طلب بدون اسم').toString(),
      customerName: (data['customerName'] ?? 'عميل').toString(),
      city: (data['city'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      workerId: (data['workerId'] ?? '').toString(),
      driverId: (data['assignedDriverId'] ?? '').toString(),
      amount: _readAmount(data),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  double _readAmount(Map<String, dynamic> data) {
    final candidates = [
      data['acceptedOfferPrice'],
      data['totalPrice'],
      data['price'],
      data['amount'],
      data['bestOfferPrice'],
    ];

    for (final value in candidates) {
      if (value is num && value.toDouble() > 0) return value.toDouble();
      final parsed = double.tryParse((value ?? '').toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    return 0;
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}