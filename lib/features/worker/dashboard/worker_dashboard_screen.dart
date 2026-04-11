import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../providers/request_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../chat/chats_list_screen.dart';
import '../profile/worker_profile_screen.dart';
import '../requests/worker_request_details_screen.dart';
import '../vehicles/add_vehicle_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VehicleProvider>().listenToMyVehicles();
      context.read<RequestProvider>().listenToWorkerRequests(
            includeOpenRequests: true,
          );
    });
  }

  @override
  void dispose() {
    context.read<RequestProvider>().stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final pages = [
      _WorkerOverviewTab(onOpenChats: () => setState(() => _currentIndex = 3)),
      const _WorkerRequestsTab(),
      const _WorkerVehiclesTab(),
      const ChatsListScreen(),
      const WorkerProfileScreen(),
    ];

    return Scaffold(
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
            icon: const Icon(Icons.directions_car_outlined),
            selectedIcon: const Icon(Icons.directions_car),
            label: l10n.translate('my_vehicles'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.translate('chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.translate('profile'),
          ),
        ],
      ),
    );
  }
}

class _WorkerRequestsTab extends StatelessWidget {
  const _WorkerRequestsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RequestProvider>();
    final workerRequests = provider.requests;

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (workerRequests.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            l10n.translate('no_assigned_requests_now'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('my_requests'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: workerRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = workerRequests[index];
          final partName =
              (request['partName'] ?? l10n.translate('unnamed_request')).toString();
          final vehicle =
              '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}';
          final status = (request['status'] ?? '').toString();

          return Card(
            child: ListTile(
              title: Text(partName),
              subtitle: Text(
                '$vehicle\n${l10n.translate('status')}: ${_statusText(status, l10n)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerRequestDetailsScreen(request: request),
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

class _WorkerVehiclesTab extends StatelessWidget {
  const _WorkerVehiclesTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicleProvider = context.watch<VehicleProvider>();

    if (vehicleProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (vehicleProvider.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.translate('my_vehicles'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              vehicleProvider.errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
            );

            if (created == true && context.mounted) {
              context.read<VehicleProvider>().listenToMyVehicles();
            }
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.translate('add_vehicle')),
        ),
      );
    }

    final vehicles = vehicleProvider.vehicles;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('my_vehicles'))),
      body: vehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        l10n.translate('no_vehicles_added_yet'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('add_vehicle_to_appear_for_review'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                context.read<VehicleProvider>().listenToMyVehicles();
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];

                  final make = (vehicle['make'] ?? '').toString();
                  final model = (vehicle['model'] ?? '').toString();
                  final year = (vehicle['year'] ?? '').toString();
                  final city = (vehicle['city'] ?? '').toString();
                  final status = (vehicle['status'] ?? '').toString();
                  final coverImage = (vehicle['coverImage'] ??
                          vehicle['cover'] ??
                          vehicle['vehicleCoverImage'] ??
                          '')
                      .toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (coverImage.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: Image.network(
                              coverImage,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: double.infinity,
                                  height: 180,
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: const BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              size: 48,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$make $model $year',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusText(status, l10n),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _VehicleInfoRow(
                                label: l10n.translate('city'),
                                value: city.isEmpty ? '-' : city,
                              ),
                              _VehicleInfoRow(
                                label: l10n.translate('damage_type'),
                                value: _damageTypeText(
                                  (vehicle['damageType'] ?? '').toString(),
                                  l10n,
                                ),
                              ),
                              _VehicleInfoRow(
                                label: l10n.translate('scrapyard'),
                                value: (vehicle['scrapyardName'] ?? '-').toString(),
                                isLast: true,
                              ),
                              if ((vehicle['visibleParts'] as List?) != null &&
                                  (vehicle['visibleParts'] as List).isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (vehicle['visibleParts'] as List)
                                      .map(
                                        (part) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _partLabel(part.toString(), l10n),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
          );

          if (created == true && context.mounted) {
            context.read<VehicleProvider>().listenToMyVehicles();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('add_vehicle')),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'published':
        return l10n.translate('published');
      case 'pending':
        return l10n.translate('pending_review');
      case 'rejected':
        return l10n.translate('rejected');
      default:
        return l10n.translate('unknown');
    }
  }

  String _damageTypeText(String value, AppLocalizations l10n) {
    switch (value) {
      case 'front':
        return l10n.translate('damage_front');
      case 'rear':
        return l10n.translate('damage_rear');
      case 'leftSide':
        return l10n.translate('damage_left_side');
      case 'rightSide':
        return l10n.translate('damage_right_side');
      case 'rollover':
        return l10n.translate('damage_rollover');
      case 'flood':
        return l10n.translate('damage_flood');
      case 'fire':
        return l10n.translate('damage_fire');
      default:
        return l10n.translate('unknown');
    }
  }

  String _partLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'door':
        return l10n.translate('part_door');
      case 'mirror':
        return l10n.translate('part_mirror');
      case 'bumper':
        return l10n.translate('part_bumper');
      case 'tail_light':
        return l10n.translate('part_tail_light');
      case 'rim':
        return l10n.translate('part_rim');
      case 'engine':
        return l10n.translate('part_engine');
      case 'gearbox':
        return l10n.translate('part_gearbox');
      case 'dashboard':
        return l10n.translate('part_dashboard');
      case 'seats':
        return l10n.translate('part_seats');
      case 'screen':
        return l10n.translate('part_screen');
      default:
        return value;
    }
  }
}

class _WorkerOverviewTab extends StatelessWidget {
  final VoidCallback onOpenChats;

  const _WorkerOverviewTab({
    required this.onOpenChats,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicleProvider = context.watch<VehicleProvider>();
    final requestProvider = context.watch<RequestProvider>();
    final currentUserId = vehicleProvider.currentUserId ?? '';

    final myVehicles = vehicleProvider.vehicles.where((v) {
      final workerId = (v['workerId'] ?? '').toString().trim();
      return workerId == currentUserId;
    }).toList();

    final pendingVehicles =
        myVehicles.where((v) => (v['status'] ?? '') == 'pending').toList();
    final publishedVehicles =
        myVehicles.where((v) => (v['status'] ?? '') == 'published').toList();

    final myRequests = requestProvider.requests;
    final assignedRequests =
        myRequests.where((r) => (r['status'] ?? '') == 'assigned').toList();
    final shippedRequests =
        myRequests.where((r) => (r['status'] ?? '') == 'shipped').toList();
    final deliveredRequests =
        myRequests.where((r) => (r['status'] ?? '') == 'delivered').toList();

    return AppGradientBackground(
      child: SafeArea(
        child: CustomScrollView(
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
                            l10n.translate('worker_dashboard'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('worker_dashboard_subtitle'),
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
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('ready_to_work'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('worker_dashboard_hint'),
                        style: const TextStyle(
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenChats,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(l10n.translate('open_chats')),
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
                        label: l10n.translate('my_vehicles'),
                        value: myVehicles.length.toString(),
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
                        label: l10n.translate('my_requests'),
                        value: myRequests.length.toString(),
                        icon: Icons.assignment_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('in_execution'),
                        value: assignedRequests.length.toString(),
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l10n.translate('shipped'),
                        value: shippedRequests.length.toString(),
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  l10n.translate('quick_summary'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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
                        label: l10n.translate('added_vehicles'),
                        value: myVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: l10n.translate('vehicles_waiting_approval'),
                        value: pendingVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: l10n.translate('published_vehicles'),
                        value: publishedVehicles.length.toString(),
                      ),
                      _SummaryRow(
                        label: l10n.translate('completed_requests'),
                        value: deliveredRequests.length.toString(),
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
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _VehicleInfoRow({
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
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
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
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}