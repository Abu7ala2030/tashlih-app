import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/location_service.dart'; // ✅ جديد
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
    LocationService.instance.stopTracking(); // ✅ إيقاف عند الخروج
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
        const SnackBar(content: Text('أدخل سعرًا صحيحًا')),
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
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// 🚀 أهم تعديل هنا
  Future<void> _markShipped() async {
    final requestId = (widget.request['id'] ?? '').toString();
    if (requestId.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      // 🔥 تحديث الحالة
      await context.read<RequestProvider>().markRequestShipped(
            requestId: requestId,
          );

      // 🔥 تشغيل التتبع
      await LocationService.instance.startTracking(
        workerId: _workerId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بدأ التتبع وتم الشحن')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
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

      // 🛑 إيقاف التتبع بعد التسليم
      LocationService.instance.stopTracking();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التسليم')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = (request['status'] ?? '').toString();

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'تفاصيل الطلب',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (status == 'assigned')
                ElevatedButton(
                  onPressed: _markShipped,
                  child: const Text('تم الشحن'),
                ),
              if (status == 'shipped')
                ElevatedButton(
                  onPressed: _markDelivered,
                  child: const Text('تم التسليم'),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}