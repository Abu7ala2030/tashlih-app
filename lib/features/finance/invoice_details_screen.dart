import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../data/models/payment_method_option.dart';
import '../../data/services/firestore_paths.dart';
import '../../data/services/payment_session_service.dart';
import '../../routes/app_routes.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  PaymentMethodOption selectedMethod = const PaymentMethodOption(
    provider: PaymentProviderType.card,
    methodCode: 'card',
  );

  bool isCreatingSession = false;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatMoney(BuildContext context, dynamic value) {
    final l10n = AppLocalizations.of(context);
    return '${_asDouble(value).toStringAsFixed(2)} ${l10n.translate('sar')}';
  }

  String _statusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'paid':
        return l10n.translate('paid');
      case 'cancelled':
        return l10n.translate('cancelled');
      case 'initiated':
        return l10n.translate('payment_initiated');
      case 'failed':
        return l10n.translate('payment_failed');
      default:
        return l10n.translate('unpaid');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'initiated':
        return Colors.blue;
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  String _dateText(BuildContext context, dynamic value) {
    final l10n = AppLocalizations.of(context);
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return l10n.translate('no_date');
  }

  Future<void> _updateInvoicePaymentStatus({
    required BuildContext context,
    required String status,
  }) async {
    final l10n = AppLocalizations.of(context);

    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.invoices)
          .doc(widget.invoiceId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final txSnapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.financialTransactions)
          .where('invoiceId', isEqualTo: widget.invoiceId)
          .get();

      for (final doc in txSnapshot.docs) {
        await doc.reference.update({
          'status': status == 'paid' ? 'paid' : 'open',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'paid'
                  ? l10n.translate('invoice_marked_paid')
                  : l10n.translate('invoice_marked_unpaid'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('invoice_status_update_failed')}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _createPaymentSession() async {
    final l10n = AppLocalizations.of(context);

    setState(() => isCreatingSession = true);

    try {
      final sessionId = await PaymentSessionService.instance.createPaymentSession(
        invoiceId: widget.invoiceId,
        method: selectedMethod,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.translate('payment_session_created_successfully')}: $sessionId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('create_payment_session_failed')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isCreatingSession = false);
      }
    }
  }

  void _openCheckoutUrl({
    required String url,
    required String title,
  }) {
    if (url.trim().isEmpty) return;

    Navigator.pushNamed(
      context,
      AppRoutes.paymentCheckout,
      arguments: {
        'url': url,
        'title': title,
      },
    );
  }

  String _paymentMethodLabel(AppLocalizations l10n, PaymentMethodOption option) {
    switch (option.provider) {
      case PaymentProviderType.card:
        return l10n.translate('payment_method_card');
      case PaymentProviderType.cashOnDelivery:
        return l10n.translate('payment_method_cod');
      case PaymentProviderType.tabby:
        return l10n.translate('payment_method_tabby');
      case PaymentProviderType.tamara:
        return l10n.translate('payment_method_tamara');
    }
  }

  List<PaymentMethodOption> _methods() {
    return const [
      PaymentMethodOption(
        provider: PaymentProviderType.card,
        methodCode: 'card',
      ),
      PaymentMethodOption(
        provider: PaymentProviderType.cashOnDelivery,
        methodCode: 'cod',
      ),
      PaymentMethodOption(
        provider: PaymentProviderType.tabby,
        methodCode: 'bnpl',
      ),
      PaymentMethodOption(
        provider: PaymentProviderType.tamara,
        methodCode: 'bnpl',
      ),
    ];
  }

  String _sessionStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'created':
        return l10n.translate('payment_session_ready');
      case 'initiated':
        return l10n.translate('payment_initiated');
      case 'failed':
        return l10n.translate('payment_failed');
      case 'pending_manual_payment':
        return l10n.translate('pending_manual_payment');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirestorePaths.invoices)
                .doc(widget.invoiceId)
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

              final data = invoiceSnapshot.data?.data();
              if (data == null) {
                return Center(
                  child: Text(
                    l10n.translate('invoice_not_found'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              final invoiceNumber = (data['invoiceNumber'] ?? '-').toString();
              final requestId = (data['requestId'] ?? '-').toString();
              final partName =
                  (data['partName'] ?? l10n.translate('unnamed_part')).toString();
              final city = (data['city'] ?? '-').toString();
              final scrapyardName = (data['scrapyardName'] ?? '-').toString();
              final currency = (data['currency'] ?? 'SAR').toString();
              final status = (data['status'] ?? 'unpaid').toString();

              final subtotal = _asDouble(data['subtotal']);
              final shippingFee = _asDouble(data['shippingFee']);
              final discount = _asDouble(data['discountAmount']);
              final totalAmount = _asDouble(data['totalAmount']);
              final commissionAmount = _asDouble(data['commissionAmount']);
              final commissionEligible =
                  (data['commissionEligible'] ?? false) == true;
              final paymentSessionId =
                  (data['paymentSessionId'] ?? '').toString().trim();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
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
                                  l10n.translate('invoice'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.translate('invoice_screen_subtitle'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoiceNumber,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatusBadge(
                                  text: _statusText(context, status),
                                  color: _statusColor(status),
                                ),
                                _InfoBadge(
                                  text: '${l10n.translate('currency')}: $currency',
                                ),
                                _InfoBadge(
                                  text: '${l10n.translate('request')}: $requestId',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              label: l10n.translate('part'),
                              value: partName,
                            ),
                            _InfoRow(
                              label: l10n.translate('city'),
                              value: city,
                            ),
                            _InfoRow(
                              label: l10n.translate('scrapyard'),
                              value: scrapyardName,
                            ),
                            _InfoRow(
                              label: l10n.translate('issue_date'),
                              value: _dateText(
                                context,
                                data['issuedAt'] ?? data['createdAt'],
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('financial_summary'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              label: l10n.translate('part_price'),
                              value: _formatMoney(context, subtotal),
                            ),
                            _InfoRow(
                              label: l10n.translate('shipping_fee'),
                              value: _formatMoney(context, shippingFee),
                            ),
                            _InfoRow(
                              label: l10n.translate('discount'),
                              value: _formatMoney(context, discount),
                            ),
                            _InfoRow(
                              label: l10n.translate('final_total'),
                              value: _formatMoney(context, totalAmount),
                              valueStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (commissionEligible)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D21),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('commission_details'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _InfoRow(
                                label: l10n.translate('due_commission'),
                                value: _formatMoney(context, commissionAmount),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('choose_payment_method'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _methods().map((method) {
                                final selected =
                                    selectedMethod.provider == method.provider;
                                return _PaymentMethodChip(
                                  label: _paymentMethodLabel(l10n, method),
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      selectedMethod = method;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            if (paymentSessionId.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _InfoRow(
                                label: l10n.translate('payment_session'),
                                value: paymentSessionId,
                                isLast: true,
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isCreatingSession
                                    ? null
                                    : _createPaymentSession,
                                icon: isCreatingSession
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.payments_outlined),
                                label: Text(
                                  l10n.translate('start_payment_session'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (paymentSessionId.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(FirestorePaths.paymentSessions)
                              .doc(paymentSessionId)
                              .snapshots(),
                          builder: (context, sessionSnapshot) {
                            final sessionData = sessionSnapshot.data?.data();
                            final sessionStatus =
                                (sessionData?['status'] ?? '').toString();
                            final checkoutUrl =
                                (sessionData?['checkoutUrl'] ?? '').toString();
                            final provider =
                                (sessionData?['provider'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D21),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('payment_session_status'),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _InfoRow(
                                    label: l10n.translate('provider'),
                                    value: provider.isEmpty ? '-' : provider,
                                  ),
                                  _InfoRow(
                                    label: l10n.translate('status'),
                                    value: sessionStatus.isEmpty
                                        ? '-'
                                        : _sessionStatusText(context, sessionStatus),
                                    isLast: checkoutUrl.isEmpty,
                                  ),
                                  if (checkoutUrl.isNotEmpty) ...[
                                    _InfoRow(
                                      label: l10n.translate('checkout_ready'),
                                      value: l10n.translate('yes'),
                                      isLast: true,
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () => _openCheckoutUrl(
                                          url: checkoutUrl,
                                          title: l10n.translate('payment_checkout'),
                                        ),
                                        icon: const Icon(Icons.open_in_new),
                                        label: Text(
                                          l10n.translate('continue_to_payment'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D21),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('payment_management'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: status == 'paid'
                                        ? null
                                        : () => _updateInvoicePaymentStatus(
                                              context: context,
                                              status: 'paid',
                                            ),
                                    child: Text(l10n.translate('mark_as_paid')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white24),
                                    ),
                                    onPressed: status != 'paid'
                                        ? null
                                        : () => _updateInvoicePaymentStatus(
                                              context: context,
                                              status: 'unpaid',
                                            ),
                                    child: Text(l10n.translate('mark_as_unpaid')),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: .08),
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
              style: valueStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;

  const _InfoBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}