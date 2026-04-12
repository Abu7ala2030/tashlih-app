import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
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

  String _roleLabel(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.customer:
        return l10n.translate('customer');
      case UserRole.worker:
        return l10n.translate('worker');
      case UserRole.admin:
        return l10n.translate('admin');
    }
  }

  String _roleDescription(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.customer:
        return l10n.translate('customer_role_description');
      case UserRole.worker:
        return l10n.translate('worker_role_description');
      case UserRole.admin:
        return l10n.translate('admin_role_description');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('choose_account_type')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D21),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('welcome_back'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('select_role_to_continue'),
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _RoleTile(
              title: _roleLabel(UserRole.customer, l10n),
              subtitle: _roleDescription(UserRole.customer, l10n),
              value: UserRole.customer,
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            const SizedBox(height: 12),
            _RoleTile(
              title: _roleLabel(UserRole.worker, l10n),
              subtitle: _roleDescription(UserRole.worker, l10n),
              value: UserRole.worker,
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            const SizedBox(height: 12),
            _RoleTile(
              title: _roleLabel(UserRole.admin, l10n),
              subtitle: _roleDescription(UserRole.admin, l10n),
              value: UserRole.admin,
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) setState(() => selectedRole = value);
              },
            ),
            const SizedBox(height: 18),
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
                    : Text(l10n.translate('login')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final UserRole value;
  final UserRole groupValue;
  final ValueChanged<UserRole?> onChanged;

  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return Material(
      color: const Color(0xFF1A1D21),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.white38 : Colors.white10,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<UserRole>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}