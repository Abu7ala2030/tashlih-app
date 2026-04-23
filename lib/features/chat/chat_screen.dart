import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/services/chat_service.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const ChatScreen({super.key, required this.chatId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;
  String senderRole = 'customer';
  Timer? _typingTimer;
  bool _typingActive = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();

    messageController.addListener(_onTypingChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      senderRole = auth.safeRole;

      try {
        await ChatService.instance.markMessagesAsRead(
          chatId: widget.chatId,
          role: senderRole,
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    messageController.removeListener(_onTypingChanged);
    _typingTimer?.cancel();
    _stopTyping();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final text = messageController.text.trim();

    if (text.isEmpty) {
      _stopTyping();
      return;
    }

    _startTyping();
  }

  void _startTyping() {
    if (!_typingActive) {
      _typingActive = true;
      ChatService.instance.setTyping(
        chatId: widget.chatId,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();

    if (_typingActive) {
      _typingActive = false;
      ChatService.instance.setTyping(
        chatId: widget.chatId,
        isTyping: false,
      );
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);

    try {
      final auth = context.read<AuthProvider>();

      await ChatService.instance.sendTextMessage(
        chatId: widget.chatId,
        text: text,
        senderRole: auth.safeRole,
      );

      _stopTyping();
      messageController.clear();

      if (scrollController.hasClients) {
        await scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('send_message_failed')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _requestShortId(String requestId) {
    final clean = requestId.trim();
    if (clean.isEmpty) return '-';
    if (clean.length <= 6) return clean.toUpperCase();
    return clean.substring(0, 6).toUpperCase();
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
        return Colors.redAccent;
      case 'available':
        return Colors.blue;
      case 'newRequest':
        return Colors.cyan;
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
        return l10n.translate('status_offer_selected');
      case 'shipped':
        return l10n.translate('status_shipped');
      case 'delivered':
        return l10n.translate('status_delivered');
      default:
        return l10n.translate('unknown');
    }
  }

  Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  String _messageStateText({
    required bool isMe,
    required Timestamp? messageCreatedAt,
    required Timestamp? otherLastSeenAt,
  }) {
    if (!isMe || messageCreatedAt == null) return '';

    if (otherLastSeenAt != null &&
        otherLastSeenAt.toDate().isAfter(
              messageCreatedAt.toDate().subtract(const Duration(seconds: 1)),
            )) {
      return l10n.translate('seen');
    }

    return l10n.translate('sent');
  }

  Widget _buildRequestHeaderCard(String requestId) {
    if (requestId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .snapshots(),
      builder: (context, snapshot) {
        final request = snapshot.data?.data();

        if (request == null) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D21),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.translate('chat_linked_to_request')} ${_requestShortId(requestId)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final partName = (request['partName'] ?? '-').toString().trim();
        final vehicleMake = (request['vehicleMake'] ?? '').toString().trim();
        final vehicleModel = (request['vehicleModel'] ?? '').toString().trim();
        final vehicleYear = (request['vehicleYear'] ?? '').toString().trim();
        final city = (request['city'] ?? '-').toString().trim();
        final status = (request['status'] ?? '').toString().trim();
        final acceptedPrice =
            (request['acceptedOfferPrice'] ?? '').toString().trim();

        final vehicle = '$vehicleMake $vehicleModel $vehicleYear'.trim();
        final statusColor = _statusColor(status);

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      partName.isEmpty
                          ? l10n.translate('unnamed_request')
                          : partName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (vehicle.isNotEmpty)
                _HeaderMetaRow(
                  icon: Icons.directions_car_outlined,
                  text: vehicle,
                ),
              const SizedBox(height: 6),
              _HeaderMetaRow(
                icon: Icons.location_city_outlined,
                text: city.isEmpty ? '-' : city,
              ),
              const SizedBox(height: 6),
              _HeaderMetaRow(
                icon: Icons.tag_outlined,
                text: '${l10n.translate('request_hash')} ${_requestShortId(requestId)}',
              ),
              if (acceptedPrice.isNotEmpty) ...[
                const SizedBox(height: 6),
                _HeaderMetaRow(
                  icon: Icons.sell_outlined,
                  text:
                      '${l10n.translate('approved_price')}: $acceptedPrice ${l10n.translate('sar')}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatAppBarTitle(
    Map<String, dynamic>? chatData,
    String myUid, {
    bool isOtherTyping = false,
  }) {
    final customerId = (chatData?['customerId'] ?? '').toString().trim();
    final workerId = (chatData?['workerId'] ?? '').toString().trim();

    final otherUserId = myUid == customerId ? workerId : customerId;

    if (otherUserId.isEmpty) {
      return Text(
        widget.title.isEmpty ? l10n.translate('chat') : widget.title,
        style: const TextStyle(color: Colors.white),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final user = snapshot.data?.data();
        final name = (user?['name'] ?? widget.title).toString().trim();
        final role = (user?['role'] ?? '').toString().trim().toLowerCase();

        String subtitle = '';
        if (isOtherTyping) {
          subtitle = l10n.translate('typing_now');
        } else if (role == 'customer') {
          subtitle = l10n.translate('customer');
        } else if (role == 'worker') {
          subtitle = l10n.translate('worker');
        } else if (role == 'driver') {
          subtitle = l10n.translate('driver');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? l10n.translate('chat') : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: isOtherTyping ? Colors.lightGreenAccent : Colors.white60,
                  fontSize: 12,
                  fontWeight: isOtherTyping ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ChatService.instance.currentUserId ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data();
        final requestId = (chatData?['requestId'] ?? '').toString().trim();

        final customerId = (chatData?['customerId'] ?? '').toString().trim();

        final otherLastSeenAt = currentUserId == customerId
            ? _readTimestamp(chatData?['workerLastSeenAt'])
            : _readTimestamp(chatData?['customerLastSeenAt']);

        final isOtherTyping = ChatService.instance.isOtherUserTyping(
          chatData: chatData,
          currentUserId: currentUserId,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0F1115),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F1115),
            elevation: 0,
            titleSpacing: 0,
            title: _buildChatAppBarTitle(
              chatData,
              currentUserId,
              isOtherTyping: isOtherTyping,
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildRequestHeaderCard(requestId),
                Expanded(
                  child: Container(
                    color: const Color(0xFF0F1115),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ChatService.instance.streamMessages(widget.chatId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                '${l10n.translate('load_messages_failed')}:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          );
                        }

                        final messages = snapshot.data?.docs ?? [];

                        if (messages.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.translate('no_messages_start_now'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final data = messages[index].data();
                            final senderId = (data['senderId'] ?? '').toString();
                            final type = (data['type'] ?? 'text').toString();
                            final text = (data['text'] ?? '').toString();
                            final createdAt = _readTimestamp(data['createdAt']);
                            final isMe = senderId == currentUserId;

                            if (type == 'system') {
                              return Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        l10n.translate('system_message'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        text,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTime(data['createdAt']),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final stateText = _messageStateText(
                              isMe: isMe,
                              messageCreatedAt: createdAt,
                              otherLastSeenAt: otherLastSeenAt,
                            );

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: const BoxConstraints(maxWidth: 280),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blueAccent.withOpacity(0.22)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isMe
                                        ? Colors.blueAccent.withOpacity(0.25)
                                        : Colors.white10,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(data['createdAt']),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (isMe && stateText.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            stateText,
                                            style: TextStyle(
                                              color: stateText ==
                                                      l10n.translate('seen')
                                                  ? Colors.lightGreenAccent
                                                  : Colors.white54,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1115),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: l10n.translate('type_your_message'),
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF1A1D21),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSending ? null : _send,
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}