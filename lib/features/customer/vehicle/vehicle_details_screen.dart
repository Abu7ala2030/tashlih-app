import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../providers/home_provider.dart';
import '../../../routes/app_routes.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  int selectedImageIndex = 0;

  AppLocalizations get l10n => AppLocalizations.of(context);

  String _damageTypeText(String value) {
    switch (value) {
      case 'front':
        return l10n.translate('damage_front');
      case 'rear':
        return l10n.translate('damage_rear');
      case 'leftSide':
        return l10n.translate('damage_left_side');
      case 'rightSide':
        return l10n.translate('damage_right_side');
      case 'rollover':
        return l10n.translate('damage_rollover');
      case 'flood':
        return l10n.translate('damage_flood');
      case 'fire':
        return l10n.translate('damage_fire');
      default:
        return l10n.translate('unknown');
    }
  }

  String _partLabel(String value) {
    switch (value) {
      case 'door':
        return l10n.translate('part_door');
      case 'mirror':
        return l10n.translate('part_mirror');
      case 'bumper':
        return l10n.translate('part_bumper');
      case 'tail_light':
        return l10n.translate('part_tail_light');
      case 'rim':
        return l10n.translate('part_rim');
      case 'engine':
        return l10n.translate('part_engine');
      case 'gearbox':
        return l10n.translate('part_gearbox');
      case 'dashboard':
        return l10n.translate('part_dashboard');
      case 'seats':
        return l10n.translate('part_seats');
      case 'screen':
        return l10n.translate('part_screen');
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<HomeProvider>().selectedVehicle;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.translate('vehicle_details'))),
        body: Center(
          child: Text(l10n.translate('no_vehicle_selected')),
        ),
      );
    }

    final media = List<String>.from(vehicle['media'] ?? []);
    final visibleParts = List<String>.from(vehicle['visibleParts'] ?? []);

    final imageUrl = media.isNotEmpty
        ? media[selectedImageIndex.clamp(0, media.length - 1)]
        : '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F1012),
              Color(0xFF15181C),
              Color(0xFF0F1012),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 360,
                      width: double.infinity,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1A1D21),
                                child: const Center(
                                  child: Icon(Icons.image_outlined, size: 72),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1A1D21),
                              child: const Center(
                                child: Icon(Icons.image_outlined, size: 72),
                              ),
                            ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.18),
                              Colors.black.withOpacity(0.25),
                              Colors.black.withOpacity(0.88),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        children: [
                          _CircleButton(
                            icon: Icons.share_outlined,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.favorite_border,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['year'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(
                                label:
                                    '${l10n.translate('city')}: ${vehicle['city'] ?? '-'}',
                              ),
                              _InfoChip(
                                label:
                                    '${l10n.translate('color')}: ${vehicle['color'] ?? '-'}',
                              ),
                              _InfoChip(
                                label:
                                    '${l10n.translate('damage_type')}: ${_damageTypeText((vehicle['damageType'] ?? '-').toString())}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (media.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 92,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      scrollDirection: Axis.horizontal,
                      itemCount: media.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final selected = index == selectedImageIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedImageIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                media[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.image_outlined),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: l10n.translate('condition_description'),
                        child: Text(
                          (vehicle['description'] ?? '').toString().isEmpty
                              ? l10n.translate('no_condition_description_available')
                              : (vehicle['description'] ?? '').toString(),
                          style: const TextStyle(
                            height: 1.7,
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: l10n.translate('visible_or_possible_parts'),
                        child: visibleParts.isEmpty
                            ? Text(
                                l10n.translate('no_parts_specified_yet'),
                                style: const TextStyle(color: Colors.white70),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: visibleParts
                                    .map(
                                      (part) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: Colors.white12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.build_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _partLabel(part),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: l10n.translate('additional_information'),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: l10n.translate('make'),
                              value: (vehicle['make'] ?? '-').toString(),
                            ),
                            _DetailRow(
                              label: l10n.translate('model'),
                              value: (vehicle['model'] ?? '-').toString(),
                            ),
                            _DetailRow(
                              label: l10n.translate('year'),
                              value: (vehicle['year'] ?? '-').toString(),
                            ),
                            _DetailRow(
                              label: l10n.translate('city'),
                              value: (vehicle['city'] ?? '-').toString(),
                            ),
                            _DetailRow(
                              label: l10n.translate('damage_type'),
                              value: _damageTypeText(
                                (vehicle['damageType'] ?? '-').toString(),
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF121417),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(.08)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.partRequest);
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(l10n.translate('request_part')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border),
                  label: Text(l10n.translate('reserve')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}