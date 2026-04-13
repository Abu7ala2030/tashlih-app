import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';

class AdminCommissionsScreen extends StatelessWidget {
  const AdminCommissionsScreen({super.key});

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirestorePaths.invoices)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, invoiceSnapshot) {
              if (invoiceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (invoiceSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'فشل تحميل الفواتير: ${invoiceSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final invoices = invoiceSnapshot.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(FirestorePaths.financialTransactions)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, txSnapshot) {
                  final transactions = txSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestorePaths.commissions)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, commissionSnapshot) {
                      final commissions = commissionSnapshot.data?.docs ?? [];

                      double totalInvoices = 0;
                      double paidInvoices = 0;
                      double openInvoices = 0;
                      for (final doc in invoices) {
                        final data = doc.data();
                        final amount = _asDouble(data['totalAmount']);
                        totalInvoices += amount;
                        final status = (data['status'] ?? 'unpaid').toString();
                        if (status == 'paid') {
                          paidInvoices += amount;
                        } else {
                          openInvoices += amount;
                        }
                      }

                      double totalCommissions = 0;
                      double pendingCommissions = 0;
                      for (final doc in commissions) {
                        final data = doc.data();
                        final amount = _asDouble(
                          data['commissionAmount'] ?? data['commissionBaseAmount'],
                        );
                        totalCommissions += amount;
                        if ((data['commissionStatus'] ?? 'pending').toString() ==
                            'pending') {
                          pendingCommissions += amount;
                        }
                      }

                      return CustomScrollView(
                        slivers: [
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'التقارير المالية',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'ملخص الفواتير والحركات المالية والعمولات',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'إجمالي الفواتير',
                                      value:
                                          '${totalInvoices.toStringAsFixed(2)} ر.س',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'المدفوع',
                                      value:
                                          '${paidInvoices.toStringAsFixed(2)} ر.س',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'غير المدفوع',
                                      value:
                                          '${openInvoices.toStringAsFixed(2)} ر.س',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'عدد الفواتير',
                                      value: invoices.length.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'عدد الحركات',
                                      value: transactions.length.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: 'العمولات المعلقة',
                                      value:
                                          '${pendingCommissions.toStringAsFixed(2)} ر.س',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                'آخر الفواتير',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (invoices.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: _EmptyCard(
                                  text: 'لا توجد فواتير حتى الآن',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              sliver: SliverList.separated(
                                itemCount: invoices.length > 10 ? 10 : invoices.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final data = invoices[index].data();
                                  final invoiceNumber =
                                      (data['invoiceNumber'] ?? '').toString();
                                  final partName =
                                      (data['partName'] ?? 'قطعة غير محددة')
                                          .toString();
                                  final totalAmount =
                                      _asDouble(data['totalAmount']);
                                  final status =
                                      (data['status'] ?? 'unpaid').toString();

                                  return _FinanceCard(
                                    title: invoiceNumber,
                                    subtitle: partName,
                                    lines: [
                                      'الإجمالي: ${totalAmount.toStringAsFixed(2)} ر.س',
                                      'الحالة: ${status == 'paid' ? 'مدفوعة' : 'غير مدفوعة'}',
                                    ],
                                  );
                                },
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                'آخر الحركات المالية',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (transactions.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: _EmptyCard(
                                  text: 'لا توجد حركات مالية حتى الآن',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              sliver: SliverList.separated(
                                itemCount: transactions.length > 10
                                    ? 10
                                    : transactions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final data = transactions[index].data();
                                  final type = (data['type'] ?? '-').toString();
                                  final amount = _asDouble(data['amount']);
                                  final status = (data['status'] ?? '-').toString();

                                  return _FinanceCard(
                                    title: type,
                                    subtitle:
                                        (data['invoiceNumber'] ?? '-').toString(),
                                    lines: [
                                      'القيمة: ${amount.toStringAsFixed(2)} ر.س',
                                      'الحالة: $status',
                                    ],
                                  );
                                },
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                'آخر العمولات',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (commissions.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 120),
                                child: _EmptyCard(
                                  text: 'لا توجد عمولات حتى الآن',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              sliver: SliverList.separated(
                                itemCount: commissions.length > 10
                                    ? 10
                                    : commissions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final data = commissions[index].data();
                                  final partName =
                                      (data['partName'] ?? 'قطعة غير محددة')
                                          .toString();
                                  final amount = _asDouble(
                                    data['commissionAmount'] ??
                                        data['commissionBaseAmount'],
                                  );
                                  final status =
                                      (data['commissionStatus'] ?? 'pending')
                                          .toString();

                                  return _FinanceCard(
                                    title: partName,
                                    subtitle:
                                        (data['invoiceNumber'] ?? '-').toString(),
                                    lines: [
                                      'العمولة: ${amount.toStringAsFixed(2)} ر.س',
                                      'الحالة: $status',
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
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

class _FinanceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> lines;

  const _FinanceCard({
    required this.title,
    required this.subtitle,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
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
            title.isEmpty ? '-' : title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}