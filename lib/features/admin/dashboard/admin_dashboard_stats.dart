class AdminDashboardStats {
  final int totalRequests;
  final int newRequests;
  final int activeRequests;
  final int completedRequests;
  final int cancelledRequests;

  final double totalRevenue;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double totalCommission;

  final int totalWorkers;
  final int totalDrivers;
  final int onlineWorkers;
  final int onlineDrivers;

  const AdminDashboardStats({
    required this.totalRequests,
    required this.newRequests,
    required this.activeRequests,
    required this.completedRequests,
    required this.cancelledRequests,
    required this.totalRevenue,
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.totalCommission,
    required this.totalWorkers,
    required this.totalDrivers,
    required this.onlineWorkers,
    required this.onlineDrivers,
  });

  factory AdminDashboardStats.empty() {
    return const AdminDashboardStats(
      totalRequests: 0,
      newRequests: 0,
      activeRequests: 0,
      completedRequests: 0,
      cancelledRequests: 0,
      totalRevenue: 0,
      todayRevenue: 0,
      weekRevenue: 0,
      monthRevenue: 0,
      totalCommission: 0,
      totalWorkers: 0,
      totalDrivers: 0,
      onlineWorkers: 0,
      onlineDrivers: 0,
    );
  }
}