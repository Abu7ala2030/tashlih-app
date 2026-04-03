import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

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
                      Text('حساب الإدارة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2)),
                      SizedBox(height: 8),
                      Text('أدر إعدادات الحساب وراقب حالة المنصة العامة من مكان واحد', style: TextStyle(color: Colors.white70, height: 1.5)),
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
                        colors: [Color(0xFF2B1D2F), Color(0xFF171A1F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 34, backgroundColor: Colors.white10, child: Icon(Icons.admin_panel_settings_outlined, size: 34)),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('مدير النظام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text('admin@demo.com', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              Text('صلاحية كاملة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
                      Expanded(child: _MiniStatCard(label: 'المركبات', value: '128', icon: Icons.directions_car_outlined)),
                      SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'الطلبات', value: '64', icon: Icons.list_alt_outlined)),
                      SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'العمال', value: '23', icon: Icons.groups_outlined)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('الإعدادات والإدارة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: const [
                      _ProfileTile(icon: Icons.settings_outlined, title: 'إعدادات المنصة', subtitle: 'الخيارات العامة والضوابط الأساسية للنظام'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.manage_accounts_outlined, title: 'إدارة الصلاحيات', subtitle: 'مراجعة الأدوار والصلاحيات الممنوحة للمستخدمين'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.notifications_none, title: 'الإشعارات', subtitle: 'متابعة التنبيهات المرتبطة بالمراجعات والطلبات'),
                      SizedBox(height: 12),
                      _ProfileTile(icon: Icons.support_agent_outlined, title: 'الدعم الفني', subtitle: 'التواصل مع الدعم عند وجود مشكلة تشغيلية'),
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
