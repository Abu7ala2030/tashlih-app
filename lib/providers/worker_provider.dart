import 'package:flutter/material.dart';

import '../data/enums/vehicle_listing_status.dart';
import '../shared/dummy/dummy_data.dart';

class WorkerProvider extends ChangeNotifier {
  int workerRequestsCount = 4;

  List get myVehicles => DummyData.vehicles;

  int get pendingReviewCount => myVehicles
      .where((v) => v.status == VehicleListingStatus.pendingReview)
      .length;

  int get publishedCount => myVehicles
      .where((v) => v.status == VehicleListingStatus.published)
      .length;
}
