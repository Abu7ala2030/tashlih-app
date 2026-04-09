class AdminWorkerSummary {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isOnline;
  final double rating;
  final int completedOrders;
  final double totalRevenue;
  final DateTime? lastSeenAt;

  const AdminWorkerSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isOnline,
    required this.rating,
    required this.completedOrders,
    required this.totalRevenue,
    required this.lastSeenAt,
  });
}