import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/hero_vehicle_banner.dart';
import '../../../core/widgets/vehicle_section_row.dart';
import '../../../providers/vehicle_provider.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  List<Map<String, dynamic>> _byBrand(
    List<Map<String, dynamic>> vehicles,
    String brand,
  ) {
    return vehicles
        .where((v) => ((v['make'] ?? '').toString().toLowerCase() == brand.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> _byDamageType(
    List<Map<String, dynamic>> vehicles,
    String damageType,
  ) {
    return vehicles
        .where((v) => ((v['damageType'] ?? '').toString() == damageType))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allPublishedVehicles = context
        .watch<VehicleProvider>()
        .vehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();

    final featuredVehicle =
        allPublishedVehicles.isNotEmpty ? allPublishedVehicles.first : null;

    final toyotaVehicles = _byBrand(allPublishedVehicles, 'Toyota');
    final hyundaiVehicles = _byBrand(allPublishedVehicles, 'Hyundai');
    final nissanVehicles = _byBrand(allPublishedVehicles, 'Nissan');
    final frontDamageVehicles = _byDamageType(allPublishedVehicles, 'front');
    final rearDamageVehicles = _byDamageType(allPublishedVehicles, 'rear');

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'تشليح بلس',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: HeroVehicleBanner(vehicle: featuredVehicle),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                  child: Row(
                    children: const [
                      Expanded(
                        child: _CategoryPill(
                          label: 'تويوتا',
                          icon: Icons.directions_car_filled_outlined,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _CategoryPill(
                          label: 'هيونداي',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _CategoryPill(
                          label: 'نيسان',
                          icon: Icons.car_crash_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (allPublishedVehicles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'لا توجد مركبات منشورة حتى الآن',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VehicleSectionRow(title: 'أضيف حديثًا', vehicles: allPublishedVehicles),
                        const SizedBox(height: 24),
                        VehicleSectionRow(title: 'تويوتا', vehicles: toyotaVehicles),
                        const SizedBox(height: 24),
                        VehicleSectionRow(title: 'هيونداي', vehicles: hyundaiVehicles),
                        const SizedBox(height: 24),
                        VehicleSectionRow(title: 'نيسان', vehicles: nissanVehicles),
                        const SizedBox(height: 24),
                        VehicleSectionRow(title: 'صدمة أمامية', vehicles: frontDamageVehicles),
                        const SizedBox(height: 24),
                        VehicleSectionRow(title: 'صدمة خلفية', vehicles: rearDamageVehicles),
                      ],
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

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CategoryPill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
