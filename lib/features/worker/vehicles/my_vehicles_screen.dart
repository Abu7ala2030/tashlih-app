import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip_filter.dart';
import '../../../providers/vehicle_provider.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  String selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final allVehicles = context.watch<VehicleProvider>().vehicles;

    final vehicles = allVehicles.where((vehicle) {
      if (selectedStatus == 'all') return true;
      return (vehicle['status'] ?? '') == selectedStatus;
    }).toList();

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
                      Text(
                        'مركباتي',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'تابع حالة المركبات التي أضفتها واعرف ما تم نشره أو ما يزال قيد المراجعة',
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: StatCard(label: 'الكل', value: allVehicles.length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'قيد المراجعة', value: allVehicles.where((v) => (v['status'] ?? '') == 'pending').length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'منشورة', value: allVehicles.where((v) => (v['status'] ?? '') == 'published').length.toString())),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      StatusChipFilter(label: 'الكل', selected: selectedStatus == 'all', onTap: () => setState(() => selectedStatus = 'all')),
                      StatusChipFilter(label: 'قيد المراجعة', selected: selectedStatus == 'pending', onTap: () => setState(() => selectedStatus = 'pending')),
                      StatusChipFilter(label: 'منشورة', selected: selectedStatus == 'published', onTap: () => setState(() => selectedStatus = 'published')),
                      StatusChipFilter(label: 'مرفوضة', selected: selectedStatus == 'rejected', onTap: () => setState(() => selectedStatus = 'rejected')),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(child: Text('المركبات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                      Text('${vehicles.length} مركبة', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              if (vehicles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.directions_car_outlined,
                        title: 'لا توجد مركبات ضمن هذه الحالة',
                        subtitle: 'بمجرد إضافة مركبات جديدة ستظهر هنا لتتابع حالتها.',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final coverImage = (vehicle['coverImage'] ?? '').toString();
                      final status = (vehicle['status'] ?? '').toString();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: coverImage.isNotEmpty
                                  ? Image.network(coverImage, width: 92, height: 92, fit: BoxFit.cover)
                                  : Container(width: 92, height: 92, color: Colors.black26, child: const Icon(Icons.image_outlined)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['year'] ?? ''}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('المدينة: ${vehicle['city'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 6),
                                  Text('الضرر: ${vehicle['damageType'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _statusText(status),
                                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'published':
        return 'منشورة';
      case 'pending':
        return 'قيد المراجعة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return 'غير معروف';
    }
  }
}
