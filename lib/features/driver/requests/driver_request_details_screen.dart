import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../providers/request_provider.dart';

class DriverRequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const DriverRequestDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  State<DriverRequestDetailsScreen> createState() =>
      _DriverRequestDetailsScreenState();
}

class _DriverRequestDetailsScreenState extends State<DriverRequestDetailsScreen> {
  bool isSubmitting = false;

  String get _requestId => (widget.request['id'] ?? '').toString();

  Future<void> _callCustomer() async {
    final phone = (widget.request['phone'] ?? widget.request['customerPhone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم العميل غير متوفر')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر إجراء الاتصال')),
    );
  }

  Future<void> _runAction(Future<void> Function() action, String success) async {
    if (_requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      await action();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _deliveryStatusText(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
        return 'بانتظار بدء التنفيذ';
      case 'pending_pickup':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      default:
        if (status == 'assigned') return 'تم إسناد الطلب';
        if (status == 'shipped') return 'قيد التوصيل';
        if (status == 'delivered') return 'تم التسليم';
        return 'قيد المعالجة';
    }
  }

  Color _statusColor(String deliveryStatus, String status) {
    switch (deliveryStatus) {
      case 'awaiting_driver_assignment':
      case 'pending_pickup':
        return Colors.orange;
      case 'picked_up':
        return Colors.teal;
      case 'on_the_way':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      default:
        if (status == 'delivered') return Colors.green;
        if (status == 'assigned' || status == 'shipped') return Colors.orange;
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final partName = (request['partName'] ?? '').toString();
    final vehicle =
        '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}'
            .trim();
    final deliveryAddress = (request['deliveryAddress'] ?? '').toString().trim();
    final customerPhone = (request['phone'] ?? '').toString().trim();
    final scrapyardName = (request['scrapyardName'] ?? '').toString().trim();
    final notes = (request['notes'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();
    final deliveryStatus =
        (request['deliveryStatus'] ?? '').toString().trim();

    final statusText = _deliveryStatusText(deliveryStatus, status);
    final statusColor = _statusColor(deliveryStatus, status);

    return Stack(
      children: [
        Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'تفاصيل طلب السائق',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            partName.isEmpty ? 'طلب بدون اسم' : partName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'معلومات الطلب',
                    child: Column(
                      children: [
                        _DetailRow(label: 'المركبة', value: vehicle.isEmpty ? '-' : vehicle),
                        _DetailRow(
                          label: 'عنوان العميل',
                          value: deliveryAddress.isEmpty ? 'غير محدد' : deliveryAddress,
                        ),
                        _DetailRow(
                          label: 'هاتف العميل',
                          value: customerPhone.isEmpty ? 'غير متوفر' : customerPhone,
                        ),
                        _DetailRow(
                          label: 'التشليح',
                          value: scrapyardName.isEmpty ? 'غير محدد' : scrapyardName,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'ملاحظات',
                    child: Text(
                      notes.isEmpty ? 'لا توجد ملاحظات' : notes,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'إجراءات السائق',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _callCustomer,
                            icon: const Icon(Icons.phone_outlined),
                            label: const Text('اتصال بالعميل'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (deliveryStatus == 'awaiting_driver_assignment' ||
                            deliveryStatus == 'pending_pickup')
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => _runAction(
                                        () => context
                                            .read<RequestProvider>()
                                            .markDriverPickedUp(requestId: _requestId),
                                        'تم تأكيد استلام الطلب',
                                      ),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('تأكيد الاستلام من العامل/التشليح'),
                            ),
                          ),
                        if (deliveryStatus == 'picked_up') ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => _runAction(
                                        () => context
                                            .read<RequestProvider>()
                                            .markDriverOnTheWay(requestId: _requestId),
                                        'تم تحديث الحالة إلى في الطريق',
                                      ),
                              icon: const Icon(Icons.route_outlined),
                              label: const Text('بدأت التوصيل للعميل'),
                            ),
                          ),
                        ],
                        if (deliveryStatus == 'on_the_way' || status == 'shipped') ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => _runAction(
                                        () => context
                                            .read<RequestProvider>()
                                            .markDriverDelivered(requestId: _requestId),
                                        'تم تأكيد التسليم',
                                      ),
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('تأكيد التسليم للعميل'),
                            ),
                          ),
                        ],
                        if (deliveryStatus == 'delivered' || status == 'delivered')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'هذا الطلب مكتمل وتم تسليمه.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isSubmitting)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
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
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
