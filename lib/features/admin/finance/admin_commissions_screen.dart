import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';

class AdminCommissionsScreen extends StatefulWidget {
  const AdminCommissionsScreen({super.key});

  @override
  State<AdminCommissionsScreen> createState() => _AdminCommissionsScreenState();
}

class _AdminCommissionsScreenState extends State<AdminCommissionsScreen> {
  final TextEditingController commissionPercentController =
      TextEditingController(text: '10');

  String selectedStatus = 'all';
  String? updatingCommissionId;

  @override
  void dispose() {
    commissionPercentController.dispose();
    super.dispose();
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  Future<void> _updateCommissionStatus({
    required String commissionId,
    required String status,
  }) async {
    setState(() => updatingCommissionId = commissionId);

    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.commissions)
          .doc(commissionId)
          .update({
        'commissionStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'paid'
                ? l10n.translate('commission_marked_paid')
                : l10n.translate('commission_marked_cancelled'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('commission_status_update_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => updatingCommissionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commissionPercent =
        double.tryParse(commissionPercentController.text.trim()) ?? 0;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('commissions_dashboard'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('commissions_dashboard_subtitle'),
                            style: const TextStyle(color: Colors.white70),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate('commission_percent'),
                          style: const TextStyle(
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
              SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StatusChip(
                      label: l10n.translate('all'),
                      selected: selectedStatus == 'all',
                      onTap: () => setState(() => selectedStatus = 'all'),
                    ),
                    _StatusChip(
                      label: l10n.translate('pending'),
                      selected: selectedStatus == 'pending',
                      onTap: () => setState(() => selectedStatus = 'pending'),
                    ),
                    _StatusChip(
                      label: l10n.translate('paid'),
                      selected: selectedStatus == 'paid',
                      onTap: () => setState(() => selectedStatus = 'paid'),
                    ),
                    _StatusChip(
                      label: l10n.translate('cancelled'),
                      selected: selectedStatus == 'cancelled',
                      onTap: () => setState(() => selectedStatus = 'cancelled'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestorePaths.commissions)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                            '${l10n.translate('load_commissions_failed')}: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final commissions = docs.where((doc) {
                      if (selectedStatus == 'all') return true;
                      return (doc.data()['commissionStatus'] ?? '').toString() ==
                          selectedStatus;
                    }).toList();

                    double totalSales = 0;
                    double totalCommission = 0;

                    for (final doc in commissions) {
                      final data = doc.data();
                      final rawSale = data['saleAmount'] ?? 0;
                      final sale = rawSale is num
                          ? rawSale.toDouble()
                          : double.tryParse(rawSale.toString()) ?? 0;
                      totalSales += sale;
                      totalCommission += (sale * commissionPercent / 100);
                    }

                    if (commissions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.translate('no_commission_records_in_status'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TopStatCard(
                                  label: l10n.translate('records_count'),
                                  value: commissions.length.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TopStatCard(
                                  label: l10n.translate('total_sales'),
                                  value:
                                      '${totalSales.toStringAsFixed(2)} ${l10n.translate('sar')}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TopStatCard(
                                  label: l10n.translate('total_commission'),
                                  value:
                                      '${totalCommission.toStringAsFixed(2)} ${l10n.translate('sar')}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                            itemCount: commissions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = commissions[index];
                              final commissionId = doc.id;
                              final data = doc.data();

                              final workerId =
                                  (data['workerId'] ?? '').toString();
                              final scrapyardName =
                                  (data['scrapyardName'] ?? l10n.translate('not_specified'))
                                      .toString();
                              final city =
                                  (data['city'] ?? l10n.translate('not_specified'))
                                      .toString();
                              final partName =
                                  (data['partName'] ?? l10n.translate('unnamed_part'))
                                      .toString();
                              final status =
                                  (data['commissionStatus'] ?? 'pending')
                                      .toString();

                              final rawSale = data['saleAmount'] ?? 0;
                              final saleAmount = rawSale is num
                                  ? rawSale.toDouble()
                                  : double.tryParse(rawSale.toString()) ?? 0;

                              final commissionAmount =
                                  saleAmount * commissionPercent / 100;

                              final createdAt = data['createdAt'];
                              final createdAtText = createdAt is Timestamp
                                  ? createdAt.toDate().toString()
                                  : l10n.translate('no_date');

                              final isUpdating =
                                  updatingCommissionId == commissionId;

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
                                      (workerData['name'] ?? l10n.translate('unnamed_worker'))
                                          .toString();
                                  final workerPhone =
                                      (workerData['phone'] ?? l10n.translate('no_phone'))
                                          .toString();

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1D21),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _InfoLine(
                                          label: l10n.translate('worker'),
                                          value: workerName,
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('worker_phone'),
                                          value: workerPhone,
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('scrapyard'),
                                          value: scrapyardName,
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('city'),
                                          value: city,
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('sale_value'),
                                          value:
                                              '${saleAmount.toStringAsFixed(2)} ${l10n.translate('sar')}',
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('commission'),
                                          value:
                                              '${commissionAmount.toStringAsFixed(2)} ${l10n.translate('sar')}',
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('status'),
                                          value: _statusText(status),
                                          valueColor: _statusColor(status),
                                        ),
                                        _InfoLine(
                                          label: l10n.translate('date'),
                                          value: createdAtText,
                                          isLast: true,
                                        ),
                                        if (status == 'pending') ...[
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton(
                                                  style:
                                                      FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        Colors.black,
                                                  ),
                                                  onPressed: isUpdating
                                                      ? null
                                                      : () =>
                                                          _updateCommissionStatus(
                                                            commissionId:
                                                                commissionId,
                                                            status: 'paid',
                                                          ),
                                                  child: isUpdating
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : Text(
                                                          l10n.translate('confirm_payment'),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: FilledButton(
                                                  style:
                                                      FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF2B1D1D),
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  onPressed: isUpdating
                                                      ? null
                                                      : () =>
                                                          _updateCommissionStatus(
                                                            commissionId:
                                                                commissionId,
                                                            status: 'cancelled',
                                                          ),
                                                  child: Text(
                                                    l10n.translate('cancel_commission'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'paid':
        return l10n.translate('paid');
      case 'cancelled':
        return l10n.translate('cancelled');
      default:
        return l10n.translate('pending');
    }
  }
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
          const SizedBox(height: 4),
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final Color? valueColor;

  const _InfoLine({
    required this.label,
    required this.value,
    this.isLast = false,
    this.valueColor,
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
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : Colors.white10,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}