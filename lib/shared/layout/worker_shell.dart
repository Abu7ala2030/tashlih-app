import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/worker/dashboard/worker_dashboard_screen.dart';
import '../../features/worker/profile/worker_profile_screen.dart';
import '../../features/worker/requests/worker_requests_screen.dart';
import '../../features/worker/vehicles/add_vehicle_screen.dart';
import '../../features/worker/vehicles/my_vehicles_screen.dart';

class WorkerShell extends StatefulWidget {
  const WorkerShell({super.key});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int currentIndex = 0;

  final pages = const [
    WorkerDashboardScreen(),
    AddVehicleScreen(),
    MyVehiclesScreen(),
    WorkerRequestsScreen(),
    WorkerProfileScreen(),
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
            icon: const Icon(Icons.add_box_outlined),
            label: l10n.translate('add'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.directions_car_outlined),
            label: l10n.translate('my_vehicles'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
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