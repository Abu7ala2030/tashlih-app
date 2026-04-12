import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/home_provider.dart';
import '../../routes/app_routes.dart';

class VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VehicleCard({
    super.key,
    required this.vehicle,
  });

  String _statusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'published':
        return l10n.translate('available');
      case 'pending':
        return l10n.translate('pending_review');
      case 'rejected':
        return l10n.translate('rejected');
      default:
        return l10n.translate('unknown');
    }
  }

  String _damageTypeText(String damageType, AppLocalizations l10n) {
    switch (damageType) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final coverImage = (vehicle['coverImage'] ?? '').toString();
    final make = (vehicle['make'] ?? '').toString();
    final model = (vehicle['model'] ?? '').toString();
    final year = (vehicle['year'] ?? '').toString();
    final city = (vehicle['city'] ?? '').toString();
    final status = (vehicle['status'] ?? '').toString();
    final damageType = (vehicle['damageType'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        context.read<HomeProvider>().setSelectedVehicle(vehicle);
        Navigator.pushNamed(context, AppRoutes.vehicleDetails);
      },
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: coverImage.isNotEmpty
                        ? Image.network(
                            coverImage,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.directions_car, size: 48),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Icon(Icons.directions_car, size: 48),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(18)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.08),
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusText(status, l10n),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (damageType.isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _damageTypeText(damageType, l10n),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$make $model',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$year • $city',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        context.read<HomeProvider>().setSelectedVehicle(vehicle);
                        Navigator.pushNamed(context, AppRoutes.vehicleDetails);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(l10n.translate('view')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        context.read<HomeProvider>().setSelectedVehicle(vehicle);
                        Navigator.pushNamed(context, AppRoutes.partRequest);
                      },
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        return Colors.blueGrey;
    }
  }
}