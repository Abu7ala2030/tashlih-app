import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../shared/layout/admin_shell.dart';
import '../../shared/layout/customer_shell.dart';
import '../../shared/layout/worker_shell.dart';
import 'login_screen.dart';

class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    if (!auth.authResolved || auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.errorMessage != null && !auth.isLoggedIn) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(l10n.translate('back_to_login')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!auth.isLoggedIn || auth.currentUser == null) {
      return const LoginScreen();
    }

    final role = auth.currentUser!.role.toLowerCase().trim();

    if (role == 'admin') {
      return const AdminShell();
    }

    if (role == 'worker') {
      return const WorkerShell();
    }

    return const CustomerShell();
  }
}