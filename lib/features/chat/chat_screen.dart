import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/chat_service.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;
  String senderRole = 'customer';

  @override
  void initState() {
    super.initState();

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
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
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

      messageController.clear();

      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الرسالة: $e')),
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
        return 'طلب جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'تم تقديم عرض';
      case 'unavailable':
        return 'غير متوفر';
      case 'assigned':
        return 'تم اختيار العرض';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'غير معروف';
    }
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
                    'المحادثة مرتبطة بطلب #${_requestShortId(requestId)}',
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
                      partName.isEmpty ? 'طلب بدون اسم' : partName,
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
                text: 'طلب #${_requestShortId(requestId)}',
              ),
              if (acceptedPrice.isNotEmpty) ...[
                const SizedBox(height: 6),
                _HeaderMetaRow(
                  icon: Icons.sell_outlined,
                  text: 'السعر المعتمد: $acceptedPrice ريال',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatAppBarTitle(Map<String, dynamic>? chatData, String myUid) {
    final customerId = (chatData?['customerId'] ?? '').toString().trim();
    final workerId = (chatData?['workerId'] ?? '').toString().trim();

    final otherUserId = myUid == customerId ? workerId : customerId;

    if (otherUserId.isEmpty) {
      return Text(
        widget.title.isEmpty ? 'المحادثة' : widget.title,
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

        String roleText = '';
        if (role == 'customer') roleText = 'عميل';
        if (role == 'worker') roleText = 'عامل';
        if (role == 'driver') roleText = 'سائق';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'المحادثة' : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (roleText.isNotEmpty)
              Text(
                roleText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
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

        return Scaffold(
          backgroundColor: const Color(0xFF0F1115),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F1115),
            elevation: 0,
            titleSpacing: 0,
            title: _buildChatAppBarTitle(chatData, currentUserId),
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
                                'فشل تحميل الرسائل:\n${snapshot.error}',
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
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'لا توجد رسائل بعد.\nابدأ أول رسالة الآن.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
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
                            final text = (data['text'] ?? '').toString();
                            final isMe = senderId == currentUserId;

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
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF1F2937),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isMe ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text.isEmpty ? '...' : text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.5,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 2,
                                            color: Colors.black45,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(data['createdAt']),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
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
                    border: Border(
                      top: BorderSide(color: Colors.white10),
                    ),
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
                            hintText: 'اكتب رسالتك...',
                            hintStyle:
                                const TextStyle(color: Colors.white54),
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
                              borderSide:
                                  const BorderSide(color: Colors.white24),
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

  const _HeaderMetaRow({
    required this.icon,
    required this.text,
  });

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