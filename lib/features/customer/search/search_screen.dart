import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
                      Text(
                        l10n.translate('search'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('search_subtitle'),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        onChanged: (value) => homeProvider.updateSearchQuery(
                          value,
                          publishedVehicles,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.translate('search_vehicle_hint'),
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
                        label: l10n.translate('all'),
                        selected: homeProvider.selectedBrand == 'الكل' ||
                            homeProvider.selectedBrand == 'all',
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
                      Expanded(
                        child: _MiniStatCard(
                          label: l10n.translate('all_results'),
                          value: filtered.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          label: l10n.translate('brand_toyota'),
                          value: filtered
                              .where((v) =>
                                  ((v['make'] ?? '').toString().toLowerCase() ==
                                      'toyota'))
                              .length
                              .toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          label: l10n.translate('brand_hyundai'),
                          value: filtered
                              .where((v) =>
                                  ((v['make'] ?? '').toString().toLowerCase() ==
                                      'hyundai'))
                              .length
                              .toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate('results'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${filtered.length} ${l10n.translate('vehicle_count_suffix_single')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _EmptySearchView(
                        title: l10n.translate('no_matching_results'),
                        subtitle: l10n.translate('search_empty_subtitle'),
                      ),
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

  const _MiniStatCard({
    required this.label,
    required this.value,
  });

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
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptySearchView({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_outlined, size: 56),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}