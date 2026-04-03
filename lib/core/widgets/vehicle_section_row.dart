import 'package:flutter/material.dart';

import 'vehicle_card.dart';

class VehicleSectionRow extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> vehicles;

  const VehicleSectionRow({
    super.key,
    required this.title,
    required this.vehicles,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => VehicleCard(vehicle: vehicles[index]),
          ),
        ),
      ],
    );
  }
}
