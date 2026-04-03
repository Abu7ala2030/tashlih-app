import '../../data/enums/damage_type.dart';
import '../../data/enums/vehicle_listing_status.dart';
import '../../data/models/vehicle_listing.dart';
import '../../data/models/vehicle_media.dart';

class DummyData {
  static final vehicles = [
    VehicleListing(
      id: '1',
      workerId: 'w1',
      make: 'Toyota',
      model: 'Camry',
      year: 2018,
      color: 'White',
      damageType: DamageType.front,
      city: 'Dammam',
      description: 'صدمة أمامية والمرايات والأبواب تبدو سليمة',
      visibleParts: ['باب', 'مرآة', 'اسطب', 'جنط'],
      media: [
        VehicleMedia(id: 'm1', url: '', isVideo: false, type: 'cover'),
      ],
      status: VehicleListingStatus.published,
      createdAt: DateTime.now(),
    ),
    VehicleListing(
      id: '2',
      workerId: 'w2',
      make: 'Hyundai',
      model: 'Elantra',
      year: 2020,
      color: 'Gray',
      damageType: DamageType.rear,
      city: 'Dammam',
      description: 'صدمة خلفية',
      visibleParts: ['باب', 'مكينة', 'قير'],
      media: [
        VehicleMedia(id: 'm2', url: '', isVideo: false, type: 'cover'),
      ],
      status: VehicleListingStatus.published,
      createdAt: DateTime.now(),
    ),
  ];
}
