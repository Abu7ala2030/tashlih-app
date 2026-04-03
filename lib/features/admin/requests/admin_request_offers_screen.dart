import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import 'admin_request_timeline_screen.dart';

class AdminRequestOffersScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const AdminRequestOffersScreen({
    super.key,
    required this.request,
  });

  @override
  State<AdminRequestOffersScreen> createState() =>
      _AdminRequestOffersScreenState();
}

class _AdminRequestOffersScreenState extends State<AdminRequestOffersScreen> {
  final TextEditingController commissionPercentController =
      TextEditingController(text: '10');

  bool isUpdatingStatus = false;

  @override
  void dispose() {
    commissionPercentController.dispose();
    super.dispose();
  }

  Future<void> _openMap(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateRequestStatus(String status) async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    setState(() => isUpdatingStatus = true);

    try {
      final payload = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'shipped') {
        payload['shippedAt'] = FieldValue.serverTimestamp();
      }

      if (status == 'delivered') {
        payload['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection(FirestorePaths.requests)
          .doc(requestId)
          .update(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusSuccessMessage(status))),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث حالة الطلب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isUpdatingStatus = false);
      }
    }
  }

  String _statusSuccessMessage(String status) {
    switch (status) {
      case 'assigned':
        return 'تم تحديث الطلب إلى تم اختيار العرض';
      case 'shipped':
        return 'تم تحديث الطلب إلى تم الشحن';
      case 'delivered':
        return 'تم تحديث الطلب إلى تم التسليم';
      default:
        return 'تم تحديث حالة الطلب';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = (widget.request['id'] ?? '').toString();

    final scrapyardName =
        (widget.request['scrapyardName'] ?? 'غير محدد').toString();
    final scrapyardLocation =
        (widget.request['scrapyardLocation'] ?? '').toString();
    final city = (widget.request['city'] ?? 'غير محددة').toString();
    final listedByWorkerId =
        (widget.request['listedByWorkerId'] ?? '').toString();
    final currentStatus = (widget.request['status'] ?? '').toString();

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عروض الطلب للإدارة',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'مراجعة العامل والتشليح والعمولة',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات المصدر',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'اسم التشليح', value: scrapyardName),
                      _InfoRow(label: 'المدينة', value: city),
                      _InfoRow(
                        label: 'العامل الرافع للمركبة',
                        value: listedByWorkerId.isEmpty
                            ? 'غير محدد'
                            : listedByWorkerId,
                        isLast: true,
                      ),
                      if (scrapyardLocation.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMap(scrapyardLocation),
                            icon: const Icon(Icons.location_on_outlined),
                            label: const Text('فتح موقع التشليح'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التحكم اليدوي في التتبع',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'الحالة الحالية: ${_requestStatusText(currentStatus)}',
                        style: TextStyle(
                          color: _requestStatusColor(currentStatus),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isUpdatingStatus
                                  ? null
                                  : () => _updateRequestStatus('assigned'),
                              child: const Text('تم اختيار العرض'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isUpdatingStatus
                                  ? null
                                  : () => _updateRequestStatus('shipped'),
                              child: const Text('تم الشحن'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isUpdatingStatus
                              ? null
                              : () => _updateRequestStatus('delivered'),
                          child: isUpdatingStatus
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('تم التسليم'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminRequestTimelineScreen(request: widget.request),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('فتح السجل الزمني للطلب'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'نسبة العمولة %',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: commissionPercentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '10',
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestorePaths.requests)
                      .doc(requestId)
                      .collection('offers')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, offersSnapshot) {
                    if (offersSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (offersSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'فشل تحميل العروض: ${offersSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final offers = offersSnapshot.data?.docs ?? [];

                    if (offers.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'لا توجد عروض على هذا الطلب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final offerDoc = offers[index];
                        final offer = offerDoc.data();

                        final workerId = (offer['workerId'] ?? '').toString();
                        final status = (offer['status'] ?? 'pending').toString();

                        final rawPrice = offer['price'];
                        final double price = rawPrice is num
                            ? rawPrice.toDouble()
                            : double.tryParse(rawPrice.toString()) ?? 0.0;

                        return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection(FirestorePaths.users)
                              .doc(workerId)
                              .get(),
                          builder: (context, workerSnapshot) {
                            final workerData =
                                workerSnapshot.data?.data() ??
                                    <String, dynamic>{};

                            final workerName =
                                (workerData['name'] ?? 'عامل بدون اسم')
                                    .toString();
                            final workerPhone =
                                (workerData['phone'] ?? 'بدون رقم').toString();
                            final workerScrapyardName =
                                (workerData['scrapyardName'] ?? scrapyardName)
                                    .toString();
                            final workerScrapyardLocation =
                                (workerData['scrapyardGoogleMapsUrl'] ??
                                        scrapyardLocation)
                                    .toString();

                            final eligible = listedByWorkerId.isNotEmpty &&
                                listedByWorkerId == workerId;

                            final commissionPercent = double.tryParse(
                                  commissionPercentController.text.trim(),
                                ) ??
                                0;

                            final commissionAmount =
                                eligible ? (price * commissionPercent / 100) : 0.0;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D21),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'رقم العامل: $workerPhone',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'اسم التشليح: $workerScrapyardName',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'المدينة: $city',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'سعر العرض: ${price.toStringAsFixed(2)} ريال',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'حالة العرض: ${_offerStatusText(status)}',
                                    style: TextStyle(
                                      color: _offerStatusColor(status),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'العامل الرافع للمركبة: ${listedByWorkerId.isEmpty ? 'غير محدد' : listedByWorkerId}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'نفس العامل الذي عرض المركبة؟ ${eligible ? 'نعم' : 'لا'}',
                                          style: TextStyle(
                                            color: eligible
                                                ? Colors.green
                                                : Colors.orange,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'العمولة المستحقة: ${commissionAmount.toStringAsFixed(2)} ريال',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (workerScrapyardLocation.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openMap(workerScrapyardLocation),
                                        icon: const Icon(
                                          Icons.location_on_outlined,
                                        ),
                                        label: const Text('فتح موقع التشليح'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _offerStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _offerStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'بانتظار الرد';
    }
  }

  Color _requestStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.teal;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _requestStatusText(String status) {
    switch (status) {
      case 'assigned':
        return 'تم اختيار العرض';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'قيد المعالجة';
    }
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
