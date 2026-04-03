import 'package:flutter/material.dart';

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
            icon: Icon(Icons.fact_check_outlined),
            label: 'المراجعة',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
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
