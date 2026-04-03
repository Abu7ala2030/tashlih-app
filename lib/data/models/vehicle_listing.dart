import '../enums/damage_type.dart';
import '../enums/vehicle_listing_status.dart';
import 'vehicle_media.dart';

class VehicleListing {
  final String id;
  final String workerId;
  final String make;
  final String model;
  final int year;
  final String color;
  final DamageType damageType;
  final String city;
  final String description;
  final List<String> visibleParts;
  final List<VehicleMedia> media;
  final VehicleListingStatus status;
  final DateTime createdAt;

  VehicleListing({
    required this.id,
    required this.workerId,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.damageType,
    required this.city,
    required this.description,
    required this.visibleParts,
    required this.media,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'damageType': damageType.name,
      'city': city,
      'description': description,
      'visibleParts': visibleParts,
      'media': media.map((e) => e.toMap()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VehicleListing.fromMap(Map<String, dynamic> map) {
    return VehicleListing(
      id: map['id'] ?? '',
      workerId: map['workerId'] ?? '',
      make: map['make'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      color: map['color'] ?? '',
      damageType: DamageType.values.firstWhere(
        (e) => e.name == map['damageType'],
        orElse: () => DamageType.unknown,
      ),
      city: map['city'] ?? '',
      description: map['description'] ?? '',
      visibleParts: List<String>.from(map['visibleParts'] ?? []),
      media: (map['media'] as List<dynamic>? ?? [])
          .map((e) => VehicleMedia.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      status: VehicleListingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VehicleListingStatus.pendingReview,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
