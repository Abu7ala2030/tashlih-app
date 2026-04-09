import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../data/services/firestore_paths.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/admin_recent_request.dart';
import '../models/admin_worker_summary.dart';

class AdminDashboardBundle {
  final AdminDashboardStats stats;
  final List<AdminRecentRequest> recentRequests;
  final List<AdminWorkerSummary> topWorkers;

  const AdminDashboardBundle({
    required this.stats,
    required this.recentRequests,
    required this.topWorkers,
  });
}

class AdminDashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<AdminDashboardBundle> loadDashboardData() async {
    final requestsSnapshot =
        await _db.collection(FirestorePaths.requests).get();

    final commissionsSnapshot =
        await _db.collection(FirestorePaths.commissions).get();

    final workers = await _loadPeople(
      primaryCollection: FirestorePaths.workers,
      fallbackRole: 'worker',
    );

    final drivers = await _loadPeople(
      primaryCollection: FirestorePaths.drivers,
      fallbackRole: 'driver',
    );

    final allRequests = requestsSnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();

    final stats = _buildStats(
      requests: allRequests,
      commissions: commissionsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList(),
      workers: workers,
      drivers: drivers,
    );

    final recentRequests = _buildRecentRequests(allRequests);
    final topWorkers = _buildTopWorkers(
      workers: workers,
      requests: allRequests,
    );

    return AdminDashboardBundle(
      stats: stats,
      recentRequests: recentRequests,
      topWorkers: topWorkers,
    );
  }

  Future<List<Map<String, dynamic>>> _loadPeople({
    required String primaryCollection,
    required String fallbackRole,
  }) async {
    final primarySnapshot = await _db.collection(primaryCollection).get();

    if (primarySnapshot.docs.isNotEmpty) {
      return primarySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    }

    final usersSnapshot = await _db
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: fallbackRole)
        .get();

    return usersSnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  AdminDashboardStats _buildStats({
    required List<Map<String, dynamic>> requests,
    required List<Map<String, dynamic>> commissions,
    required List<Map<String, dynamic>> workers,
    required List<Map<String, dynamic>> drivers,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int newRequests = 0;
    int activeRequests = 0;
    int completedRequests = 0;
    int cancelledRequests = 0;

    double totalRevenue = 0;
    double todayRevenue = 0;
    double weekRevenue = 0;
    double monthRevenue = 0;

    for (final request in requests) {
      final status = (request['status'] ?? '').toString();
      final amount = _extractRequestAmount(request);
      final eventDate = _extractBestRequestDate(request);

      if (status == 'newRequest') {
        newRequests++;
      } else if (_isCompletedStatus(status)) {
        completedRequests++;
      } else if (status == 'cancelled') {
        cancelledRequests++;
      } else if (_isActiveStatus(status)) {
        activeRequests++;
      }

      if (_isRevenueEligibleStatus(status)) {
        totalRevenue += amount;

        if (eventDate != null) {
          if (!eventDate.isBefore(startOfToday)) {
            todayRevenue += amount;
          }
          if (!eventDate.isBefore(startOfWeek)) {
            weekRevenue += amount;
          }
          if (!eventDate.isBefore(startOfMonth)) {
            monthRevenue += amount;
          }
        }
      }
    }

    double totalCommission = 0;
    for (final commission in commissions) {
      totalCommission += _extractCommissionAmount(commission);
    }

    final onlineWorkers = workers.where(_isPersonOnline).length;
    final onlineDrivers = drivers.where(_isPersonOnline).length;

    return AdminDashboardStats(
      totalRequests: requests.length,
      newRequests: newRequests,
      activeRequests: activeRequests,
      completedRequests: completedRequests,
      cancelledRequests: cancelledRequests,
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      weekRevenue: weekRevenue,
      monthRevenue: monthRevenue,
      totalCommission: totalCommission,
      totalWorkers: workers.length,
      totalDrivers: drivers.length,
      onlineWorkers: onlineWorkers,
      onlineDrivers: onlineDrivers,
    );
  }

  List<AdminRecentRequest> _buildRecentRequests(
    List<Map<String, dynamic>> requests,
  ) {
    final items = requests.map((request) {
      return AdminRecentRequest(
        id: (request['id'] ?? '').toString(),
        partName: (request['partName'] ?? 'طلب بدون اسم').toString(),
        customerName: (request['customerName'] ?? 'عميل').toString(),
        city: (request['city'] ?? '').toString(),
        status: (request['status'] ?? '').toString(),
        workerId: (request['workerId'] ?? '').toString(),
        driverId: (request['assignedDriverId'] ?? '').toString(),
        amount: _extractRequestAmount(request),
        createdAt: _timestampToDateTime(request['createdAt']),
      );
    }).toList();

    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items.take(10).toList();
  }

  List<AdminWorkerSummary> _buildTopWorkers({
    required List<Map<String, dynamic>> workers,
    required List<Map<String, dynamic>> requests,
  }) {
    final completedStatuses = {'delivered', 'completed'};

    final result = workers.map((worker) {
      final workerId = (worker['id'] ?? '').toString();

      final workerRequests = requests.where((request) {
        return (request['workerId'] ?? '').toString() == workerId;
      }).toList();

      final completedOrders = workerRequests.where((request) {
        final status = (request['status'] ?? '').toString();
        return completedStatuses.contains(status);
      }).length;

      final totalRevenue = workerRequests.fold<double>(
        0,
        (sum, request) => sum + _extractRequestAmount(request),
      );

      return AdminWorkerSummary(
        id: workerId,
        name: _extractPersonName(worker),
        phone: _extractPersonPhone(worker),
        role: (worker['role'] ?? 'worker').toString(),
        isOnline: _isPersonOnline(worker),
        rating: _extractRating(worker),
        completedOrders: completedOrders,
        totalRevenue: totalRevenue,
        lastSeenAt: _timestampToDateTime(
          worker['lastSeenAt'] ?? worker['updatedAt'],
        ),
      );
    }).toList();

    result.sort((a, b) {
      final completedCompare = b.completedOrders.compareTo(a.completedOrders);
      if (completedCompare != 0) return completedCompare;
      return b.totalRevenue.compareTo(a.totalRevenue);
    });

    return result.take(5).toList();
  }

  bool _isActiveStatus(String status) {
    return {
      'checkingAvailability',
      'available',
      'assigned',
      'accepted',
      'inProgress',
      'processing',
      'ready',
      'shipped',
    }.contains(status);
  }

  bool _isCompletedStatus(String status) {
    return {'delivered', 'completed'}.contains(status);
  }

  bool _isRevenueEligibleStatus(String status) {
    return {
      'assigned',
      'accepted',
      'shipped',
      'delivered',
      'completed',
    }.contains(status);
  }

  double _extractRequestAmount(Map<String, dynamic> data) {
    final candidates = [
      data['acceptedOfferPrice'],
      data['totalPrice'],
      data['price'],
      data['amount'],
      data['bestOfferPrice'],
      data['commissionBaseAmount'],
    ];

    for (final value in candidates) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  double _extractCommissionAmount(Map<String, dynamic> data) {
    final directCandidates = [
      data['commissionAmount'],
      data['amount'],
      data['value'],
      data['platformCommission'],
    ];

    for (final value in directCandidates) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }

    final baseAmount = _toDouble(
      data['commissionBaseAmount'] ?? data['saleAmount'],
    );
    final percent = _toDouble(
      data['commissionPercent'] ?? data['percent'],
    );

    if (baseAmount > 0 && percent > 0) {
      return baseAmount * percent / 100;
    }

    return 0;
  }

  String _extractPersonName(Map<String, dynamic> data) {
    final candidates = [
      data['name'],
      data['fullName'],
      data['displayName'],
      data['scrapyardName'],
      data['title'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    return 'بدون اسم';
  }

  String _extractPersonPhone(Map<String, dynamic> data) {
    final candidates = [
      data['phone'],
      data['mobile'],
      data['phoneNumber'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    return 'بدون رقم';
  }

  double _extractRating(Map<String, dynamic> data) {
    final candidates = [
      data['rating'],
      data['averageRating'],
    ];

    for (final value in candidates) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }

    return 0;
  }

  bool _isPersonOnline(Map<String, dynamic> data) {
    final onlineFlags = [
      data['isOnline'],
      data['online'],
      data['availableNow'],
    ];

    for (final value in onlineFlags) {
      if (value == true) return true;
    }

    final status = (data['availabilityStatus'] ?? data['status'] ?? '')
        .toString()
        .toLowerCase();

    return status == 'online' || status == 'active';
  }

  DateTime? _extractBestRequestDate(Map<String, dynamic> request) {
    return _timestampToDateTime(
          request['deliveredAt'],
        ) ??
        _timestampToDateTime(
          request['completedAt'],
        ) ??
        _timestampToDateTime(
          request['assignedAt'],
        ) ??
        _timestampToDateTime(
          request['createdAt'],
        );
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}