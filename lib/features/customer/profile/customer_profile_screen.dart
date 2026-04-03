import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حسابي', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2)),
                      SizedBox(height: 8),
                      Text('أدر بياناتك وتابع طلباتك وإعدادات التطبيق من مكان واحد', style: TextStyle(color: Colors.white70, height: 1.5)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF20252B), Color(0xFF171A1F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 34, backgroundColor: Colors.white10, child: Icon(Icons.person, size: 34)),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('مستخدم تجريبي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text('0500000000', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              Text('عميل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Row(
                    children: const [
                      Expanded(child: _MiniStatCard(label: 'طلباتي', value: '12', icon: Icons.inventory_2_outlined)),
                      SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'المحفوظات', value: '4', icon: Icons.bookmark_border)),
                      SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'الإشعارات', value: '3', icon: Icons.notifications_none)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: const [
                      _ProfileTile(icon: Icons.person_outline, title: 'البيانات الشخصية', subtitle: 'الاسم ورقم الجوال ومعلومات الحساب'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.location_on_outlined, title: 'العناوين', subtitle: 'إدارة المدن والعناوين المرتبطة بطلباتك'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.support_agent_outlined, title: 'الدعم الفني', subtitle: 'تواصل مع الدعم عند وجود مشكلة أو استفسار'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.settings_outlined, title: 'إعدادات التطبيق', subtitle: 'الإشعارات واللغة والتفضيلات العامة'),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B1D1D), foregroundColor: Colors.white),
                      onPressed: () {},
                      child: const Text('تسجيل الخروج'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)), child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.45)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
