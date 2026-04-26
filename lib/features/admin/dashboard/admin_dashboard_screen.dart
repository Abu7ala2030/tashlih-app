import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../finance/admin_commissions_screen.dart';
import '../requests/admin_request_offers_screen.dart';
import '../review/review_vehicle_screen.dart';
import '../workers/manage_workers_screen.dart';
import '../drivers/manage_drivers_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final pages = [
      const _AdminOverviewTab(),
      const _AdminRequestsTab(),
      const ManageWorkersScreen(),
      const ManageDriversScreen(),
      const AdminCommissionsScreen(),
      const ReviewVehicleScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المدير'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
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
            label: l10n.translate('requests'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.translate('workers'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: 'السائقين',
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.translate('finance'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check),
            label: l10n.translate('review'),
          ),
        ],
      ),
    );
  }
}

class _AdminRequestsTab extends StatelessWidget {
  const _AdminRequestsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RequestProvider>();
    final requests = provider.requests;

    if (requests.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            l10n.translate('no_requests_now'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('customer_requests'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = requests[index];
          final partName =
              (request['partName'] ?? l10n.translate('unnamed_request'))
                  .toString();
          final customerName =
              (request['customerName'] ?? l10n.translate('customer'))
                  .toString();
          final status = (request['status'] ?? '').toString();

          return Card(
            child: ListTile(
              title: Text(partName),
              subtitle: Text(
                '${l10n.translate('customer')}: $customerName\n'
                '${l10n.translate('status')}: ${_statusText(status, l10n)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminRequestOffersScreen(request: request),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _statusText(String status, AppLocalizations l10n) {
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
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      case 'cancelled':
        return l10n.translate('status_cancelled');
      default:
        return l10n.translate('unknown');
    }
  }
}

class _AdminOverviewTab extends StatelessWidget {
  const _AdminOverviewTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();

    final allVehicles = vehicleProvider.vehicles;
    final pendingVehicles = allVehicles
        .where((v) => (v['status'] ?? '') == 'pending')
        .toList();
    final publishedVehicles = allVehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();

    final allRequests = requestProvider.requests;
    final newRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'newRequest')
        .toList();
    final checkingRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'checkingAvailability')
        .toList();
    final availableRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'available')
        .toList();
    final assignedRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'assigned')
        .toList();
    final shippedRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'shipped')
        .toList();
    final deliveredRequests = allRequests
        .where((r) => (r['status'] ?? '') == 'delivered')
        .toList();

    return AppGradientBackground(
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
                      l10n.translate('admin_dashboard'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.translate('admin_dashboard_subtitle'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('operational_overview'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('admin_overview_hint'),
                        style: const TextStyle(
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
                        label: l10n.translate('all_vehicles'),
                        value: allVehicles.length.toString(),
                        icon: Icons.directions_car_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('pending_review'),
                        value: pendingVehicles.length.toString(),
                        icon: Icons.hourglass_top_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('published'),
                        value: publishedVehicles.length.toString(),
                        icon: Icons.verified_outlined,
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
                        label: l10n.translate('new_requests'),
                        value: newRequests.length.toString(),
                        icon: Icons.fiber_new_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('checking_availability'),
                        value: checkingRequests.length.toString(),
                        icon: Icons.search_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('offers'),
                        value: availableRequests.length.toString(),
                        icon: Icons.check_circle_outline,
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
                        label: l10n.translate('status_offer_selected'),
                        value: assignedRequests.length.toString(),
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('status_shipped'),
                        value: shippedRequests.length.toString(),
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('status_delivered'),
                        value: deliveredRequests.length.toString(),
                        icon: Icons.done_all_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _AdminActionRow(
                        icon: Icons.assignment_outlined,
                        title: l10n.translate('requests'),
                        subtitle: l10n.translate(
                          'review_request_offers_and_status',
                        ),
                      ),
                      _AdminActionRow(
                        icon: Icons.groups_outlined,
                        title: l10n.translate('workers'),
                        subtitle: l10n.translate(
                          'manage_accounts_and_approvals',
                        ),
                      ),
                      _AdminActionRow(
                        icon: Icons.payments_outlined,
                        title: l10n.translate('finance'),
                        subtitle: l10n.translate(
                          'track_commissions_and_reports',
                        ),
                      ),
                      _AdminActionRow(
                        icon: Icons.fact_check_outlined,
                        title: l10n.translate('review'),
                        subtitle: l10n.translate(
                          'approve_vehicles_and_verify_data',
                        ),
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

class _AdminActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _AdminActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(.08))),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
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
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
