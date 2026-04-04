import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'customer';
  bool isRegister = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) return;

    if (isRegister) {
      await auth.registerWithEmail(
        email: email,
        password: password,
        role: selectedRole,
      );
    } else {
      await auth.loginWithEmail(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isRegister ? 'إنشاء حساب' : 'تسجيل الدخول'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
            ),
            const SizedBox(height: 12),
            if (isRegister)
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('عميل')),
                  DropdownMenuItem(value: 'worker', child: Text('عامل')),
                  DropdownMenuItem(value: 'driver', child: Text('سائق')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selectedRole = v);
                },
                decoration: const InputDecoration(labelText: 'الدور'),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isRegister ? 'إنشاء الحساب' : 'دخول'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => isRegister = !isRegister),
              child: Text(
                isRegister ? 'عندي حساب بالفعل' : 'إنشاء حساب جديد',
              ),
            ),
            if (isRegister)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'ملاحظة: تسجيل السائق من داخل التطبيق مناسب حاليًا للاختبار. لاحقًا الأفضل إنشاء حساب السائق من الإدارة فقط.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
