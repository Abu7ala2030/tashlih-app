import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/home_provider.dart';
import '../../routes/app_routes.dart';

class HeroVehicleBanner extends StatelessWidget {
  final Map<String, dynamic>? vehicle;

  const HeroVehicleBanner({
    super.key,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Text(
            'لا توجد مركبات منشورة حاليًا',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final coverImage = (vehicle!['coverImage'] ?? '').toString();
    final make = (vehicle!['make'] ?? '').toString();
    final model = (vehicle!['model'] ?? '').toString();
    final year = (vehicle!['year'] ?? '').toString();
    final city = (vehicle!['city'] ?? '').toString();
    final description = (vehicle!['description'] ?? '').toString();

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverImage.isNotEmpty
                ? Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                  )
                : Container(color: const Color(0xFF1A1D21)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.88),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    '$make $model $year',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    city,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description.isEmpty ? 'اطلب أي قطعة من هذه السيارة بسهولة.' : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            context.read<HomeProvider>().setSelectedVehicle(vehicle!);
                            Navigator.pushNamed(context, AppRoutes.vehicleDetails);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('عرض الآن'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                          onPressed: () {
                            context.read<HomeProvider>().setSelectedVehicle(vehicle!);
                            Navigator.pushNamed(context, AppRoutes.partRequest);
                          },
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('اطلب قطعة'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
