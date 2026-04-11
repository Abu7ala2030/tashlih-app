import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../data/services/location_service.dart';
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

  String get _requestId => (widget.request['id'] ?? '').toString().trim();
  String get _customerId =>
      (widget.request['customerId'] ?? '').toString().trim();

  AppLocalizations get l10n => AppLocalizations.of(context);

  String get _workerId {
    final direct = (widget.request['workerId'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final assigned =
        (widget.request['assignedWorkerId'] ?? '').toString().trim();
    if (assigned.isNotEmpty) return assigned;

    final accepted =
        (widget.request['acceptedWorkerId'] ?? '').toString().trim();
    if (accepted.isNotEmpty) return accepted;

    return context.read<RequestProvider>().currentUserId ?? '';
  }

  bool _canOpenChat(Map<String, dynamic> request) {
    final requestId = (request['id'] ?? '').toString().trim();
    final customerId = (request['customerId'] ?? '').toString().trim();
    final status = (request['status'] ?? '').toString().trim();

    return requestId.isNotEmpty &&
        customerId.isNotEmpty &&
        _workerId.isNotEmpty &&
        (status == 'assigned' || status == 'shipped' || status == 'delivered');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _requestStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(_requestId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myOfferStream() {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(_requestId)
        .collection('offers')
        .where('workerId', isEqualTo: _workerId)
        .limit(1)
        .snapshots();
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  Future<void> _openChat(Map<String, dynamic> request) async {
    if (!_canOpenChat(request) || isOpeningChat) return;

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
            title: l10n.translate('customer_chat'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('open_chat_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isOpeningChat = false);
      }
    }
  }

  Future<void> _callCustomer(Map<String, dynamic> request) async {
    final phone = (request['phone'] ?? request['customerPhone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('customer_phone_not_available'))),
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
      SnackBar(content: Text(l10n.translate('unable_to_make_call'))),
    );
  }

  Future<void> _openMapUrl(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('unable_to_open_location'))),
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String success,
  }) async {
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
        SnackBar(content: Text('${l10n.translate('error_happened')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _submitOffer() async {
    if (_requestId.isEmpty) return;

    final rawPrice = priceController.text.trim();
    final price = double.tryParse(rawPrice);

    if (rawPrice.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_valid_offer_price'))),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final provider = context.read<RequestProvider>();

      await provider.submitOffer(
        requestId: _requestId,
        price: price,
      );

      await provider.updateRequestStatus(
        requestId: _requestId,
        status: 'available',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('offer_sent_successfully'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('send_offer_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _markShipped() async {
    await _runAction(
      action: () => context.read<RequestProvider>().markRequestShipped(
            requestId: _requestId,
          ),
      success: l10n.translate('request_marked_shipped'),
    );
  }

  Future<void> _markDelivered() async {
    await _runAction(
      action: () async {
        await context.read<RequestProvider>().markRequestDelivered(
              requestId: _requestId,
            );
        LocationService.instance.stopTracking();
      },
      success: l10n.translate('request_marked_delivered'),
    );
  }

  Future<void> _updateStatus(String status) async {
    await _runAction(
      action: () => context.read<RequestProvider>().updateRequestStatus(
            requestId: _requestId,
            status: status,
          ),
      success: l10n.translate('request_status_updated'),
    );
  }

  Color _offerStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  String _offerStatusText(String status) {
    switch (status) {
      case 'accepted':
        return l10n.translate('your_offer_accepted');
      case 'rejected':
        return l10n.translate('your_offer_rejected');
      default:
        return l10n.translate('your_offer_waiting_decision');
    }
  }

  Widget _buildMyOfferBanner() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myOfferStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final offer = docs.first.data();
        final status = (offer['status'] ?? 'pending').toString().trim();
        final price = (offer['price'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _offerStatusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _offerStatusColor(status).withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _offerStatusText(status),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _offerStatusColor(status),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price.isEmpty
                      ? l10n.translate('your_offer_recorded')
                      : '${l10n.translate('your_offer_value')}: $price ${l10n.translate('sar')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                if (status == 'rejected') ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('ignore_or_send_new_offer'),
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_requestId.isEmpty) {
      return Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(child: Text(l10n.translate('unable_load_request'))),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        final request = {
          ...widget.request,
          ...?liveData,
          'id': _requestId,
        };

        final coverImage = (request['vehicleCoverImage'] ??
                request['coverImage'] ??
                request['vehicleImage'] ??
                '')
            .toString()
            .trim();

        final status = (request['status'] ?? '').toString().trim();
        final scrapyardName =
            (request['scrapyardName'] ?? l10n.translate('not_specified'))
                .toString();
        final scrapyardLocation =
            (request['scrapyardLocation'] ??
                    request['scrapyardGoogleMapsUrl'] ??
                    '')
                .toString()
                .trim();

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
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFF1A1D21),
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_outlined,
                                              size: 72,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: const Color(0xFF1A1D21),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 72,
                                        ),
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
                                      Colors.black.withValues(alpha: 0.18),
                                      Colors.black.withValues(alpha: 0.25),
                                      Colors.black.withValues(alpha: 0.88),
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
                                  color: _statusColor(status).withValues(alpha: 0.95),
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
                              _buildMyOfferBanner(),
                              _SectionCard(
                                title: l10n.translate('request_information'),
                                child: Column(
                                  children: [
                                    _DetailRow(
                                      label: l10n.translate('requested_part'),
                                      value: (request['partName'] ?? '-')
                                          .toString(),
                                    ),
                                    _DetailRow(
                                      label: l10n.translate('vehicle'),
                                      value:
                                          '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}',
                                    ),
                                    _DetailRow(
                                      label: l10n.translate('city'),
                                      value:
                                          (request['city'] ?? '-').toString(),
                                    ),
                                    _DetailRow(
                                      label: l10n.translate('phone'),
                                      value:
                                          (request['phone'] ?? '-').toString(),
                                    ),
                                    _DetailRow(
                                      label: l10n.translate('scrapyard'),
                                      value: scrapyardName,
                                      isLast: true,
                                    ),
                                    if (scrapyardLocation.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _openMapUrl(scrapyardLocation),
                                          icon: const Icon(
                                            Icons.location_on_outlined,
                                          ),
                                          label: Text(
                                            l10n.translate('open_scrapyard_location'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                title: l10n.translate('customer_notes'),
                                child: Text(
                                  (request['notes'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? l10n.translate('no_notes')
                                      : (request['notes'] ?? '').toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                title: l10n.translate('communication'),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _callCustomer(request),
                                        icon: const Icon(Icons.phone_outlined),
                                        label: Text(l10n.translate('call_customer')),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _canOpenChat(request) &&
                                                !isOpeningChat
                                            ? () => _openChat(request)
                                            : null,
                                        icon: isOpeningChat
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.chat_bubble_outline,
                                              ),
                                        label: Text(
                                          _canOpenChat(request)
                                              ? l10n.translate('customer_chat')
                                              : l10n.translate('chat_available_after_accept'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (status == 'newRequest' ||
                                  status == 'checkingAvailability' ||
                                  status == 'unavailable' ||
                                  status == 'available')
                                _buildOfferSection()
                              else if (status == 'assigned')
                                _buildAssignedSection(request)
                              else if (status == 'shipped')
                                _buildShippedSection()
                              else
                                _buildDeliveredSection(request),
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
      },
    );
  }

  Widget _buildOfferSection() {
    return Column(
      children: [
        _SectionCard(
          title: l10n.translate('submit_price_offer'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('enter_price_for_customer'),
                style: const TextStyle(
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
                  hintText: l10n.translate('price_example'),
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
                text: l10n.translate('send_offer'),
                color: Colors.green,
                enabled: !isSubmitting,
                onTap: _submitOffer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: l10n.translate('take_alternative_action'),
          child: Column(
            children: [
              _ActionButton(
                text: l10n.translate('needs_checking'),
                color: Colors.orange,
                enabled: !isSubmitting,
                onTap: () => _updateStatus('checkingAvailability'),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                text: l10n.translate('unavailable'),
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

  Widget _buildAssignedSection(Map<String, dynamic> request) {
    final acceptedPrice = (request['acceptedOfferPrice'] ?? '-').toString();

    return _SectionCard(
      title: l10n.translate('follow_request'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.translate('selected_price')}: $acceptedPrice ${l10n.translate('sar')}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.translate('your_offer_selected_start_shipping'),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            text: l10n.translate('confirm_request_shipped'),
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
      title: l10n.translate('request_in_shipping_stage'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('request_shipped_tracking_running'),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            text: l10n.translate('confirm_delivery'),
            color: Colors.green,
            enabled: !isSubmitting,
            onTap: _markDelivered,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredSection(Map<String, dynamic> request) {
    return _SectionCard(
      title: l10n.translate('request_completed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('part_delivered_successfully'),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.translate('current_status')}: ${_statusText((request['status'] ?? '').toString())}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
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
        return l10n.translate('status_new_request');
      case 'checkingAvailability':
        return l10n.translate('status_checking');
      case 'available':
        return l10n.translate('status_offer_submitted');
      case 'unavailable':
        return l10n.translate('status_unavailable');
      case 'assigned':
        return l10n.translate('your_offer_selected');
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      default:
        return l10n.translate('unknown');
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
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
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