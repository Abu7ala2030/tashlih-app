import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/hero_vehicle_banner.dart';
import '../../../core/widgets/vehicle_section_row.dart';
import '../../../providers/vehicle_provider.dart';
import '../../chat/chats_list_screen.dart';
import '../../shared/notifications/notification_bell_button.dart';
import '../profile/customer_profile_screen.dart';
import '../requests/my_requests_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final pages = [
      _CustomerBrowseTab(
        onOpenRequests: () => setState(() => _currentIndex = 1),
        onOpenChats: () => setState(() => _currentIndex = 2),
        onOpenProfile: () => setState(() => _currentIndex = 3),
      ),
      const MyRequestsScreen(),
      const ChatsListScreen(),
      const CustomerProfileScreen(),
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
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.translate('my_requests'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.translate('chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.translate('account'),
          ),
        ],
      ),
    );
  }
}

class _CustomerBrowseTab extends StatelessWidget {
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenProfile;

  const _CustomerBrowseTab({
    required this.onOpenRequests,
    required this.onOpenChats,
    required this.onOpenProfile,
  });

  List<Map<String, dynamic>> _byBrand(
    List<Map<String, dynamic>> vehicles,
    String brand,
  ) {
    return vehicles
        .where(
          (v) =>
              ((v['make'] ?? '').toString().toLowerCase() ==
                  brand.toLowerCase()),
        )
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
    final l10n = AppLocalizations.of(context);

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
                      child: Text(
                        l10n.translate('app_brand_name'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
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
                child: HeroVehicleBanner(vehicle: featuredVehicle),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.receipt_long_outlined,
                        title: l10n.translate('my_requests'),
                        subtitle: l10n.translate('review_requests_and_offers'),
                        onTap: onOpenRequests,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.chat_bubble_outline,
                        title: l10n.translate('chats'),
                        subtitle: l10n.translate('each_chat_linked_to_request'),
                        onTap: onOpenChats,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: _QuickActionCard(
                    icon: Icons.person_outline,
                    title: l10n.translate('account'),
                    subtitle: l10n.translate('my_data_and_settings'),
                    onTap: onOpenProfile,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _CategoryPill(
                        label: l10n.translate('brand_toyota'),
                        icon: Icons.directions_car_filled_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryPill(
                        label: l10n.translate('brand_hyundai'),
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryPill(
                        label: l10n.translate('brand_nissan'),
                        icon: Icons.car_crash_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (allPublishedVehicles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    l10n.translate('no_published_vehicles_yet'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                      VehicleSectionRow(
                        title: l10n.translate('recently_added'),
                        vehicles: allPublishedVehicles,
                      ),
                      const SizedBox(height: 24),
                      VehicleSectionRow(
                        title: l10n.translate('brand_toyota'),
                        vehicles: toyotaVehicles,
                      ),
                      const SizedBox(height: 24),
                      VehicleSectionRow(
                        title: l10n.translate('brand_hyundai'),
                        vehicles: hyundaiVehicles,
                      ),
                      const SizedBox(height: 24),
                      VehicleSectionRow(
                        title: l10n.translate('brand_nissan'),
                        vehicles: nissanVehicles,
                      ),
                      const SizedBox(height: 24),
                      VehicleSectionRow(
                        title: l10n.translate('front_damage'),
                        vehicles: frontDamageVehicles,
                      ),
                      const SizedBox(height: 24),
                      VehicleSectionRow(
                        title: l10n.translate('rear_damage'),
                        vehicles: rearDamageVehicles,
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1D21),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
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