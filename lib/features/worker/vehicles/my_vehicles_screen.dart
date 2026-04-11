import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip_filter.dart';
import '../../../providers/vehicle_provider.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  String selectedStatus = 'all';

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final allVehicles = context.watch<VehicleProvider>().vehicles;

    final vehicles = allVehicles.where((vehicle) {
      if (selectedStatus == 'all') return true;
      return (vehicle['status'] ?? '') == selectedStatus;
    }).toList();

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
                        l10n.translate('my_vehicles'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('my_vehicles_subtitle'),
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
                          value: allVehicles.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('pending_review'),
                          value: allVehicles
                              .where((v) => (v['status'] ?? '') == 'pending')
                              .length
                              .toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: l10n.translate('published'),
                          value: allVehicles
                              .where((v) => (v['status'] ?? '') == 'published')
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
                        label: l10n.translate('pending_review'),
                        selected: selectedStatus == 'pending',
                        onTap: () => setState(() => selectedStatus = 'pending'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('published'),
                        selected: selectedStatus == 'published',
                        onTap: () => setState(() => selectedStatus = 'published'),
                      ),
                      StatusChipFilter(
                        label: l10n.translate('rejected'),
                        selected: selectedStatus == 'rejected',
                        onTap: () => setState(() => selectedStatus = 'rejected'),
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
                          l10n.translate('vehicles'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${vehicles.length} ${l10n.translate('vehicle_count_suffix')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (vehicles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.directions_car_outlined,
                        title: l10n.translate('no_vehicles_in_this_status'),
                        subtitle: l10n.translate('vehicles_empty_subtitle'),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final coverImage = (vehicle['coverImage'] ?? '').toString();
                      final status = (vehicle['status'] ?? '').toString();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: coverImage.isNotEmpty
                                  ? Image.network(
                                      coverImage,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 92,
                                        height: 92,
                                        color: Colors.black26,
                                        child: const Icon(Icons.image_outlined),
                                      ),
                                    )
                                  : Container(
                                      width: 92,
                                      height: 92,
                                      color: Colors.black26,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['year'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.translate('city')}: ${vehicle['city'] ?? '-'}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.translate('damage_type')}: ${_damageTypeText((vehicle['damageType'] ?? '-').toString())}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _statusText(status),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  String _damageTypeText(String value) {
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
      case 'unknown':
        return l10n.translate('unknown');
      default:
        return value;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
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
}