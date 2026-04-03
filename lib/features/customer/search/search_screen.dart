import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/vehicle_card.dart';
import '../../../providers/home_provider.dart';
import '../../../providers/vehicle_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final publishedVehicles = context
        .read<VehicleProvider>()
        .vehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();
    context.read<HomeProvider>().resetSearch(publishedVehicles);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final publishedVehicles = context
        .watch<VehicleProvider>()
        .vehicles
        .where((v) => (v['status'] ?? '') == 'published')
        .toList();

    final filtered = homeProvider.filteredVehicles;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'البحث',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ابحث عن المركبة المناسبة وشاهد صورها قبل طلب القطعة',
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        onChanged: (value) =>
                            homeProvider.updateSearchQuery(value, publishedVehicles),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن سيارة أو موديل أو مدينة',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: homeProvider.searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    homeProvider.resetSearch(publishedVehicles);
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _BrandChip(
                        label: 'الكل',
                        selected: homeProvider.selectedBrand == 'الكل',
                        onTap: () => homeProvider.selectBrand('الكل', publishedVehicles),
                      ),
                      _BrandChip(
                        label: 'Toyota',
                        selected: homeProvider.selectedBrand == 'Toyota',
                        onTap: () => homeProvider.selectBrand('Toyota', publishedVehicles),
                      ),
                      _BrandChip(
                        label: 'Hyundai',
                        selected: homeProvider.selectedBrand == 'Hyundai',
                        onTap: () => homeProvider.selectBrand('Hyundai', publishedVehicles),
                      ),
                      _BrandChip(
                        label: 'Nissan',
                        selected: homeProvider.selectedBrand == 'Nissan',
                        onTap: () => homeProvider.selectBrand('Nissan', publishedVehicles),
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
                      Expanded(child: _MiniStatCard(label: 'كل النتائج', value: filtered.length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'تويوتا', value: filtered.where((v) => ((v['make'] ?? '').toString().toLowerCase() == 'toyota')).length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: _MiniStatCard(label: 'هيونداي', value: filtered.where((v) => ((v['make'] ?? '').toString().toLowerCase() == 'hyundai')).length.toString())),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'النتائج',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text('${filtered.length} مركبة', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: _EmptySearchView(),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => VehicleCard(vehicle: filtered[index]),
                      childCount: filtered.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 290,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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

class _BrandChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BrandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Colors.white : Colors.white10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 56),
          SizedBox(height: 14),
          Text(
            'لا توجد نتائج مطابقة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'جرّب اسم سيارة مختلف أو غيّر الفئة المختارة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
