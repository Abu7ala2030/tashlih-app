import '../widgets/admin_recent_request_tile.dart';

class AdminRecentRequest extends AdminRecentRequestViewModel {
  @override
  final String id;

  @override
  final String partName;

  @override
  final String customerName;

  @override
  final String city;

  @override
  final String status;

  @override
  final String workerId;

  @override
  final String driverId;

  @override
  final double amount;

  @override
  final DateTime? createdAt;

  AdminRecentRequest({
    required this.id,
    required this.partName,
    required this.customerName,
    required this.city,
    required this.status,
    required this.workerId,
    required this.driverId,
    required this.amount,
    required this.createdAt,
  });
}