import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import '../auth/simple_login_screen.dart';
import '../customer/home/customer_home_screen.dart';
import '../worker/dashboard/worker_dashboard_screen.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.authResolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const SimpleLoginScreen();
    }

    final role = auth.role;

    if (role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (role) {
      case 'admin':
        return const AdminDashboardScreen();

      case 'worker':
        return const WorkerDashboardScreen();

      case 'customer':
      default:
        return const CustomerHomeScreen();
    }
  }
}