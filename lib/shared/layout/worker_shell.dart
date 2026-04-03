import 'package:flutter/material.dart';

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
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'إضافة',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            label: 'مركباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'الطلبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'الحساب',
          ),
        ],
      ),
    );
  }
}
