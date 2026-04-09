import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';

class AdminWorkerDetailsScreen extends StatefulWidget {
  final String personId;
  final String role;
  final Map<String, dynamic>? initialData;

  const AdminWorkerDetailsScreen({
    super.key,
    required this.personId,
    required this.role,
    this.initialData,
  });

  @override
  State<AdminWorkerDetailsScreen> createState() =>
      _AdminWorkerDetailsScreenState();
}

class _AdminWorkerDetailsScreenState extends State<AdminWorkerDetailsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<_WorkerDetailsBundle> _loadData() async {
    Map<String, dynamic> personData = widget.initialData ?? {};

    if (personData.isEmpty) {
      final primaryCollection =
          widget.role == 'driver' ? FirestorePaths.drivers : FirestorePaths.workers;

      final primaryDoc =
          await _db.collection(primaryCollection).doc(widget.personId).get();

      if (primaryDoc.exists) {
        personData = {
          'id': primaryDoc.id,
          ...?primaryDoc.data(),
        };
      } else {
        final userDoc =
            await _db.collection(FirestorePaths.users).doc(widget.personId).get();

        personData = {
          'id': userDoc.id,
          ...?userDoc.data(),
        };
      }
    }

    final requestsSnapshot = await _db
        .collection(FirestorePaths.requests)
        .orderBy('createdAt', descending: true)
        .get();

    final allRequests = requestsSnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();

    final relatedRequests = allRequests.where((request) {
      if (widget.role == 'driver') {
        return (request['assignedDriverId'] ?? '').toString() == widget.personId;
      }
      return (request['workerId'] ?? '').toString() == widget.personId;
    }).toList();

    final completedRequests = relatedRequests.where((request) {
      final status = (request['status'] ?? '').toString();
      return status == 'completed' || status == 'delivered';
    }).toList();

    final totalRevenue = relatedRequests.fold<double>(
      0,
      (sum, request) => sum + _readAmount(request),
    );

    return _WorkerDetailsBundle(
      personData: personData,
      relatedRequests: relatedRequests.take(20).toList(),
      totalRequests: relatedRequests.length,
      completedRequests: completedRequests.length,
      totalRevenue: totalRevenue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: FutureBuilder<_WorkerDetailsBundle>(
            future: _loadData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'فشل تحميل تفاصيل الحساب:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final bundle = snapshot.data;
              if (bundle == null) {
                return const Center(
                  child: Text('لا توجد بيانات'),
                );
              }

              final person = bundle.personData;

              final name = _name(person);
              final phone = _phone(person);
              final isOnline = _isOnline(person);
              final rating = _rating(person);
              final city = _text(person['city']);
              final scrapyardName = _text(person['scrapyardName']);
              final lastSeen = _dateText(
                _timestampToDateTime(person['lastSeenAt'] ?? person['updatedAt']),
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.role == 'driver'
                              ? 'تفاصيل السائق'
                              : 'تفاصيل العامل',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: isOnline
                              ? Colors.green.withOpacity(.12)
                              : Colors.white10,
                          child: Icon(
                            widget.role == 'driver'
                                ? Icons.local_shipping
                                : Icons.person,
                            size: 30,
                            color: isOnline ? Colors.green : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.green.withOpacity(.12)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOnline ? 'متصل الآن' : 'غير متصل',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.white70,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'الجوال', value: phone),
                        _InfoRow(
                          label: 'الدور',
                          value: widget.role == 'driver' ? 'سائق' : 'عامل',
                        ),
                        if (city.isNotEmpty)
                          _InfoRow(label: 'المدينة', value: city),
                        if (scrapyardName.isNotEmpty)
                          _InfoRow(label: 'التشليح', value: scrapyardName),
                        _InfoRow(
                          label: 'التقييم',
                          value: rating > 0 ? rating.toStringAsFixed(1) : 'غير متوفر',
                        ),
                        _InfoRow(label: 'آخر ظهور', value: lastSeen, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _TopStatCard(
                          label: 'كل الطلبات',
                          value: bundle.totalRequests.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopStatCard(
                          label: 'المكتملة',
                          value: bundle.completedRequests.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopStatCard(
                          label: 'الإيراد',
                          value: '${bundle.totalRevenue.toStringAsFixed(0)} ر.س',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'آخر الطلبات المرتبطة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (bundle.relatedRequests.isEmpty)
                    const _EmptyCard(
                      text: 'لا توجد طلبات مرتبطة بهذا الحساب حالياً',
                    )
                  else
                    ...bundle.relatedRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(request: request),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _name(Map<String, dynamic> data) {
    final candidates = [
      data['name'],
      data['fullName'],
      data['displayName'],
      data['scrapyardName'],
    ];

    for (final value in candidates) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }

    return 'بدون اسم';
  }

  String _phone(Map<String, dynamic> data) {
    final candidates = [
      data['phone'],
      data['mobile'],
      data['phoneNumber'],
    ];

    for (final value in candidates) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }

    return 'بدون رقم';
  }

  bool _isOnline(Map<String, dynamic> data) {
    if (data['isOnline'] == true) return true;
    if (data['online'] == true) return true;
    if (data['availableNow'] == true) return true;

    final status =
        _text(data['availabilityStatus']).toLowerCase().isNotEmpty
            ? _text(data['availabilityStatus']).toLowerCase()
            : _text(data['status']).toLowerCase();

    return status == 'online' || status == 'active';
  }

  double _rating(Map<String, dynamic> data) {
    final raw = data['rating'] ?? data['averageRating'];
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString()) ?? 0;
  }

  double _readAmount(Map<String, dynamic> data) {
    final candidates = [
      data['acceptedOfferPrice'],
      data['totalPrice'],
      data['price'],
      data['amount'],
      data['bestOfferPrice'],
    ];

    for (final value in candidates) {
      if (value is num && value.toDouble() > 0) return value.toDouble();
      final parsed = double.tryParse((value ?? '').toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    return 0;
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _text(dynamic value) => (value ?? '').toString().trim();
}

class _WorkerDetailsBundle {
  final Map<String, dynamic> personData;
  final List<Map<String, dynamic>> relatedRequests;
  final int totalRequests;
  final int completedRequests;
  final double totalRevenue;

  const _WorkerDetailsBundle({
    required this.personData,
    required this.relatedRequests,
    required this.totalRequests,
    required this.completedRequests,
    required this.totalRevenue,
  });
}

class _TopStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _TopStatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(.08),
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const _RequestCard({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final partName = (request['partName'] ?? 'طلب بدون اسم').toString();
    final customerName = (request['customerName'] ?? 'عميل').toString();
    final status = (request['status'] ?? '').toString();
    final city = (request['city'] ?? '').toString();

    final amount = _readAmount(request);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text('العميل: $customerName'),
          if (city.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('المدينة: $city'),
          ],
          const SizedBox(height: 4),
          Text('القيمة: ${amount.toStringAsFixed(2)} ر.س'),
          const SizedBox(height: 8),
          _StatusBadge(status: status),
        ],
      ),
    );
  }

  double _readAmount(Map<String, dynamic> data) {
    final candidates = [
      data['acceptedOfferPrice'],
      data['totalPrice'],
      data['price'],
      data['amount'],
      data['bestOfferPrice'],
    ];

    for (final value in candidates) {
      if (value is num && value.toDouble() > 0) return value.toDouble();
      final parsed = double.tryParse((value ?? '').toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    return 0;
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'newRequest':
        return Colors.orange;
      case 'checkingAvailability':
        return Colors.amber;
      case 'available':
        return Colors.lightGreen;
      case 'assigned':
      case 'accepted':
      case 'shipped':
        return Colors.blue;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'متاح';
      case 'assigned':
        return 'مُعيَّن';
      case 'accepted':
        return 'مقبول';
      case 'shipped':
        return 'مشحون';
      case 'delivered':
        return 'تم التسليم';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}