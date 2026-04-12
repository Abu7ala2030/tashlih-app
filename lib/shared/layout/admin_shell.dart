import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/profile/admin_profile_screen.dart';
import '../../features/admin/requests/admin_requests_screen.dart';
import '../../features/admin/review/review_vehicle_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int currentIndex = 0;

  final pages = const [
    AdminDashboardScreen(),
    ReviewVehicleScreen(),
    AdminRequestsScreen(),
    AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            label: l10n.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            label: l10n.translate('review'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            label: l10n.translate('requests'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: l10n.translate('account'),
          ),
        ],
      ),
    );
  }
}