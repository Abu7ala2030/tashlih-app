import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../chat/chat_screen.dart';

class CustomerRequestTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CustomerRequestTrackingScreen({
    super.key,
    required this.request,
  });

  @override
  State<CustomerRequestTrackingScreen> createState() =>
      _CustomerRequestTrackingScreenState();
}

class _CustomerRequestTrackingScreenState
    extends State<CustomerRequestTrackingScreen> {
  bool isOpeningChat = false;

  String get _requestId => (widget.request['id'] ?? '').toString();

  String get _customerId => (widget.request['customerId'] ?? '').toString();

  String get _workerId {
    final direct = (widget.request['workerId'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final assigned =
        (widget.request['assignedWorkerId'] ?? '').toString().trim();
    if (assigned.isNotEmpty) return assigned;

    final accepted =
        (widget.request['acceptedWorkerId'] ?? '').toString().trim();
    return accepted;
  }

  String get _status => (widget.request['status'] ?? '').toString();

  bool get _canOpenChat {
    return _requestId.isNotEmpty &&
        _customerId.isNotEmpty &&
        _workerId.isNotEmpty &&
        (_status == 'assigned' ||
            _status == 'shipped' ||
            _status == 'delivered');
  }

  Future<void> _openChat() async {
    if (!_canOpenChat || isOpeningChat) return;

    setState(() => isOpeningChat = true);

    try {
      final chatId = await ChatService.instance.createOrGetChat(
        requestId: _requestId,
        customerId: _customerId,
        workerId: _workerId,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: 'محادثة العامل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل فتح المحادثة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isOpeningChat = false);
      }
    }
  }

  Future<void> _openMap(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الموقع')),
    );
  }

  String _statusText(String status) {
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

  Color _statusColor(String status) {
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

  String _priceText() {
    final raw = widget.request['acceptedOfferPrice'] ?? '-';
    return '$raw ريال';
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = _status;
    final scrapyardName = (request['scrapyardName'] ?? 'غير محدد').toString();
    final scrapyardLocation =
        (request['scrapyardLocation'] ?? '').toString().trim();

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
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
                            const Text(
                              'تتبع الطلب',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${request['partName'] ?? ''} • ${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الحالة الحالية',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statusText(status),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _statusColor(status),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusText(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'القطعة المطلوبة',
                          value: (request['partName'] ?? '-').toString(),
                        ),
                        _InfoRow(
                          label: 'المركبة',
                          value:
                              '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                        ),
                        _InfoRow(
                          label: 'السعر المختار',
                          value: _priceText(),
                        ),
                        _InfoRow(
                          label: 'المدينة',
                          value: (request['city'] ?? '-').toString(),
                        ),
                        _InfoRow(
                          label: 'التشليح',
                          value: scrapyardName,
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
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجراءات الطلب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          status == 'assigned'
                              ? 'تم اعتماد العرض وبدأت مرحلة التنفيذ. يمكنك الآن التواصل مع العامل مباشرة.'
                              : status == 'shipped'
                                  ? 'الطلب في مرحلة الشحن. يمكنك متابعة التنسيق مع العامل عبر المحادثة.'
                                  : status == 'delivered'
                                      ? 'تم التسليم. ما زال بإمكانك الرجوع للمحادثة عند الحاجة.'
                                      : 'سيظهر زر المحادثة بعد اعتماد أحد العروض.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (_canOpenChat && !isOpeningChat)
                                ? _openChat
                                : null,
                            icon: isOpeningChat
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.chat_bubble_outline),
                            label: Text(
                              _canOpenChat
                                  ? 'محادثة العامل'
                                  : 'المحادثة متاحة بعد قبول العرض',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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