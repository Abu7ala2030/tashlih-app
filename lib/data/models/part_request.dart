import '../enums/request_status.dart';

class PartRequest {
  final String id;
  final String vehicleListingId;
  final String customerId;
  final String partName;
  final String notes;
  final String phone;
  final String city;
  final bool needsShipping;
  final RequestStatus status;
  final DateTime createdAt;

  PartRequest({
    required this.id,
    required this.vehicleListingId,
    required this.customerId,
    required this.partName,
    required this.notes,
    required this.phone,
    required this.city,
    required this.needsShipping,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleListingId': vehicleListingId,
      'customerId': customerId,
      'partName': partName,
      'notes': notes,
      'phone': phone,
      'city': city,
      'needsShipping': needsShipping,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PartRequest.fromMap(Map<String, dynamic> map) {
    return PartRequest(
      id: map['id'] ?? '',
      vehicleListingId: map['vehicleListingId'] ?? '',
      customerId: map['customerId'] ?? '',
      partName: map['partName'] ?? '',
      notes: map['notes'] ?? '',
      phone: map['phone'] ?? '',
      city: map['city'] ?? '',
      needsShipping: map['needsShipping'] ?? false,
      status: RequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RequestStatus.newRequest,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
