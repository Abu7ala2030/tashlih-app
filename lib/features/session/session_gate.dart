import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tashlih_app/features/admin/profile/admin_profile_screen.dart';

import '../../providers/auth_provider.dart';
import '../auth/simple_login_screen.dart';
import '../customer/home/customer_home_screen.dart';
import '../worker/profile/worker_profile_screen.dart'; // شاشة العامل

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // ⏳ لسه ما خلص التحقق من Firebase
    if (!auth.authResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ❌ غير مسجل
    if (!auth.isLoggedIn) {
      return const SimpleLoginScreen();
    }

    // 🔐 مسجل → نقرر حسب الدور
    final role = auth.role;

    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (role) {
      case 'worker':
        debugPrint('Current Role: $role');
        return const WorkerProfileScreen();

      case 'admin':
        debugPrint('Current Role: $role');
        // مؤقتًا نوديه نفس العميل (نعدلها لاحقًا)
        return const AdminProfileScreen();

      case 'customer':
      default:
        debugPrint('Current Role: $role');
        return const CustomerHomeScreen();
    }
  }
}
