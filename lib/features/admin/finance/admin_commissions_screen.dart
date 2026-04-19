import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../routes/app_routes.dart';

class AdminCommissionsScreen extends StatelessWidget {
  const AdminCommissionsScreen({super.key});

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(BuildContext context, dynamic value) {
    final l10n = AppLocalizations.of(context);
    return '${_asDouble(value).toStringAsFixed(2)} ${l10n.translate('sar')}';
  }

  String _invoiceStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'paid':
        return l10n.translate('paid');
      case 'cancelled':
        return l10n.translate('cancelled');
      default:
        return l10n.translate('unpaid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                      '${l10n.translate('load_invoice_failed')}: ${invoiceSnapshot.error}',
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
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('financial_reports'),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.translate('financial_reports_subtitle'),
                                    style: const TextStyle(
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
                                      label: l10n.translate('total_invoices'),
                                      value: _money(context, totalInvoices),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: l10n.translate('paid_total'),
                                      value: _money(context, paidInvoices),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: l10n.translate('unpaid_total'),
                                      value: _money(context, openInvoices),
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
                                      label: l10n.translate('invoice_count'),
                                      value: invoices.length.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: l10n.translate('transactions_count'),
                                      value: transactions.length.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TopStatCard(
                                      label: l10n.translate('pending_commissions_total'),
                                      value: _money(context, pendingCommissions),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                l10n.translate('latest_invoices'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (invoices.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _EmptyCard(
                                  text: l10n.translate('no_invoices_yet'),
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
                                  final doc = invoices[index];
                                  final data = doc.data();
                                  final invoiceId = doc.id;
                                  final invoiceNumber =
                                      (data['invoiceNumber'] ?? '').toString();
                                  final partName =
                                      (data['partName'] ?? l10n.translate('unnamed_part'))
                                          .toString();
                                  final totalAmount =
                                      _asDouble(data['totalAmount']);
                                  final status =
                                      (data['status'] ?? 'unpaid').toString();

                                  return _FinanceCard(
                                    title: invoiceNumber,
                                    subtitle: partName,
                                    lines: [
                                      '${l10n.translate('total')}: ${_money(context, totalAmount)}',
                                      '${l10n.translate('status')}: ${_invoiceStatusText(context, status)}',
                                    ],
                                    actionLabel: l10n.translate('view_invoice'),
                                    onAction: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.invoiceDetails,
                                        arguments: invoiceId,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                l10n.translate('latest_transactions'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (transactions.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _EmptyCard(
                                  text: l10n.translate('no_transactions_yet'),
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
                                      '${l10n.translate('amount')}: ${_money(context, amount)}',
                                      '${l10n.translate('status')}: $status',
                                    ],
                                  );
                                },
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                              child: Text(
                                l10n.translate('latest_commissions'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (commissions.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                child: _EmptyCard(
                                  text: l10n.translate('no_commissions_yet'),
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
                                      (data['partName'] ?? l10n.translate('unnamed_part'))
                                          .toString();
                                  final amount = _asDouble(
                                    data['commissionAmount'] ??
                                        data['commissionBaseAmount'],
                                  );
                                  final status =
                                      (data['commissionStatus'] ?? 'pending')
                                          .toString();
                                  final invoiceId =
                                      (data['invoiceId'] ?? '').toString().trim();

                                  return _FinanceCard(
                                    title: partName,
                                    subtitle:
                                        (data['invoiceNumber'] ?? '-').toString(),
                                    lines: [
                                      '${l10n.translate('commission')}: ${_money(context, amount)}',
                                      '${l10n.translate('status')}: $status',
                                    ],
                                    actionLabel: invoiceId.isEmpty
                                        ? null
                                        : l10n.translate('view_invoice'),
                                    onAction: invoiceId.isEmpty
                                        ? null
                                        : () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.invoiceDetails,
                                              arguments: invoiceId,
                                            );
                                          },
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
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FinanceCard({
    required this.title,
    required this.subtitle,
    required this.lines,
    this.actionLabel,
    this.onAction,
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(actionLabel!),
              ),
            ),
          ],
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