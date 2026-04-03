import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../providers/request_provider.dart';
import '../../chat/chat_screen.dart';

class WorkerRequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const WorkerRequestDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  State<WorkerRequestDetailsScreen> createState() =>
      _WorkerRequestDetailsScreenState();
}

class _WorkerRequestDetailsScreenState
    extends State<WorkerRequestDetailsScreen> {
  bool isSubmitting = false;
  bool isOpeningChat = false;
  final TextEditingController priceController = TextEditingController();

  String get _requestId => (widget.request['id'] ?? '').toString();
  String get _customerId => (widget.request['customerId'] ?? '').toString();

  String get _workerId {
    final direct = (widget.request['workerId'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final assigned = (widget.request['assignedWorkerId'] ?? '').toString().trim();
    if (assigned.isNotEmpty) return assigned;

    final accepted = (widget.request['acceptedWorkerId'] ?? '').toString().trim();
    if (accepted.isNotEmpty) return accepted;

    return context.read<RequestProvider>().currentUserId ?? '';
  }

  bool get _canOpenChat {
    final status = (widget.request['status'] ?? '').toString();
    return _requestId.isNotEmpty &&
        _customerId.isNotEmpty &&
        _workerId.isNotEmpty &&
        (status == 'assigned' || status == 'shipped' || status == 'delivered');
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
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
            title: 'محادثة العميل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل فتح المحادثة: $e')),
      );
    } finally {
      if (mounted) setState(() => isOpeningChat = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      await context.read<RequestProvider>().updateRequestStatus(
            requestId: requestId,
            status: status,
          );

      if (!mounted) return;
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

  Future<void> _submitOffer() async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    final rawPrice = priceController.text.trim();
    final price = double.tryParse(rawPrice);

    if (rawPrice.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل سعرًا صحيحًا للعرض')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final provider = context.read<RequestProvider>();

      await provider.submitOffer(
        requestId: requestId,
        price: price,
      );

      await provider.updateRequestStatus(
        requestId: requestId,
        status: 'available',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال العرض بنجاح')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال العرض: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _markShipped() async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      await context.read<RequestProvider>().markRequestShipped(
            requestId: requestId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الطلب إلى تم الشحن')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث حالة الشحن: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _markDelivered() async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      await context.read<RequestProvider>().markRequestDelivered(
            requestId: requestId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الطلب إلى تم التسليم')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث حالة التسليم: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final coverImage = (request['vehicleCoverImage'] ?? '').toString();
    final status = (request['status'] ?? '').toString();

    return Stack(
      children: [
        Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: coverImage.isNotEmpty
                              ? Image.network(
                                  coverImage,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: const Color(0xFF1A1D21),
                                  child: const Center(
                                    child: Icon(Icons.image_outlined, size: 72),
                                  ),
                                ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.25),
                                  Colors.black.withOpacity(0.88),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _CircleButton(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(.95),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusText(status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (request['partName'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionCard(
                            title: 'معلومات الطلب',
                            child: Column(
                              children: [
                                _DetailRow(
                                  label: 'القطعة المطلوبة',
                                  value: (request['partName'] ?? '-').toString(),
                                ),
                                _DetailRow(
                                  label: 'المركبة',
                                  value:
                                      '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                                ),
                                _DetailRow(
                                  label: 'المدينة',
                                  value: (request['city'] ?? '-').toString(),
                                ),
                                _DetailRow(
                                  label: 'رقم التواصل',
                                  value: (request['phone'] ?? '-').toString(),
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'ملاحظات العميل',
                            child: Text(
                              (request['notes'] ?? '').toString().isEmpty
                                  ? 'لا توجد ملاحظات'
                                  : (request['notes'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (status == 'newRequest' ||
                              status == 'checkingAvailability' ||
                              status == 'unavailable')
                            _buildOfferSection()
                          else if (status == 'assigned')
                            _buildAssignedSection()
                          else if (status == 'shipped')
                            _buildShippedSection()
                          else
                            _buildDeliveredSection(),
                        ],
                      ),
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
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildOfferSection() {
    return Column(
      children: [
        _SectionCard(
          title: 'تقديم عرض سعر',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل السعر الذي تريد تقديمه للعميل',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'مثال: 350',
                  prefixIcon: const Icon(Icons.sell_outlined),
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
              ),
              const SizedBox(height: 12),
              _ActionButton(
                text: 'إرسال العرض',
                color: Colors.green,
                enabled: !isSubmitting,
                onTap: _submitOffer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'اتخاذ إجراء بديل',
          child: Column(
            children: [
              _ActionButton(
                text: 'تحتاج فحص',
                color: Colors.orange,
                enabled: !isSubmitting,
                onTap: () => _updateStatus('checkingAvailability'),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                text: 'غير متوفرة',
                color: const Color(0xFF2B1D1D),
                enabled: !isSubmitting,
                onTap: () => _updateStatus('unavailable'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedSection() {
    return _SectionCard(
      title: 'متابعة الطلب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السعر المختار: ${(widget.request['acceptedOfferPrice'] ?? '-').toString()} ريال',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_canOpenChat && !isOpeningChat) ? _openChat : null,
              icon: isOpeningChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: const Text('محادثة العميل'),
            ),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            text: 'تأكيد أن الطلب تم شحنه',
            color: Colors.indigo,
            enabled: !isSubmitting,
            onTap: _markShipped,
          ),
        ],
      ),
    );
  }

  Widget _buildShippedSection() {
    return _SectionCard(
      title: 'الطلب في مرحلة الشحن',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تم تحديث الطلب إلى مرحلة الشحن. بعد وصول القطعة للعميل قم بتأكيد التسليم.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_canOpenChat && !isOpeningChat) ? _openChat : null,
              icon: isOpeningChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: const Text('محادثة العميل'),
            ),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            text: 'تأكيد التسليم',
            color: Colors.green,
            enabled: !isSubmitting,
            onTap: _markDelivered,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredSection() {
    return _SectionCard(
      title: 'اكتمل الطلب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تم تسليم القطعة للعميل بنجاح.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_canOpenChat && !isOpeningChat) ? _openChat : null,
              icon: isOpeningChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: const Text('محادثة العميل'),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.teal;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'checkingAvailability':
        return Colors.orange;
      case 'unavailable':
        return Colors.red;
      case 'available':
        return Colors.green;
      case 'newRequest':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'طلب جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'تم تقديم عرض';
      case 'unavailable':
        return 'غير متوفر';
      case 'assigned':
        return 'تم اختيار عرضك';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'غير معروف';
    }
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
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

class _ActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.text,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(text),
      ),
    );
  }
}