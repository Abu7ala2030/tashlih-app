import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/enums/user_role.dart';
import '../../providers/auth_provider.dart';
import 'role_gate_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole selectedRole = UserRole.customer;

  Future<void> _continue() async {
    final auth = context.read<AuthProvider>();
    await auth.fakeLoginAs(selectedRole);

    if (!mounted) return;

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار نوع الحساب')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RadioListTile<UserRole>(
              value: UserRole.customer,
              groupValue: selectedRole,
              title: const Text('عميل'),
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            RadioListTile<UserRole>(
              value: UserRole.worker,
              groupValue: selectedRole,
              title: const Text('عامل'),
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            RadioListTile<UserRole>(
              value: UserRole.admin,
              groupValue: selectedRole,
              title: const Text('مدير'),
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _continue,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('دخول'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
