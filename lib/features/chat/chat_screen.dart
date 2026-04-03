import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool isSending = false;

  String senderRole = 'customer';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      senderRole = auth.safeRole;

      await ChatService.instance.markMessagesAsRead(
        chatId: widget.chatId,
        role: senderRole,
      );
    });
  }

  Future<void> _openPhone(String phone) async {
    final cleaned = phone.replaceAll(' ', '').replaceAll('-', '');
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _normalizePhoneForWhatsApp(String phone) {
    var value = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (value.startsWith('+')) return value.substring(1);
    if (value.startsWith('00')) return value.substring(2);
    if (value.startsWith('0')) return '966${value.substring(1)}';
    if (!value.startsWith('966')) return '966$value';
    return value;
  }

  Future<void> _openWhatsApp(String phone) async {
    final normalized = _normalizePhoneForWhatsApp(phone);
    if (normalized.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLocation(String url) async {
    if (url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    messageController.dispose();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الرسالة: $e')),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ChatService.instance.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, chatSnap) {
            if (!chatSnap.hasData) {
              return const Text('المحادثة');
            }

            final chatData = chatSnap.data!.data();
            if (chatData == null) {
              return const Text('المحادثة');
            }

            final auth = context.watch<AuthProvider>();
            final myUid = auth.uid;
            final isAdmin = auth.role == 'admin'; // 🔥 مهم

            final customerId = chatData['customerId'];
            final workerId = chatData['workerId'];

            final otherUserId =
                myUid == customerId ? workerId : customerId;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || userSnap.data!.data() == null) {
                  return const Text('...');
                }

                final user = userSnap.data!.data()!;
                final name = user['name'] ?? 'مستخدم';
                final photo = user['photoUrl'] ?? '';
                final rating = user['rating']?.toString() ?? '';
                final phone = (user['phone'] ?? '').toString();
                final whatsapp = (user['whatsapp'] ?? phone).toString();
                final locationUrl =
                    (user['locationUrl'] ?? '').toString();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontSize: 16)),
                          if (rating.isNotEmpty)
                            Text(
                              '⭐ $rating',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),

                    // 🔒 تظهر فقط للإدارة
                    if (isAdmin && phone.isNotEmpty)
                      IconButton(
                        onPressed: () => _openPhone(phone),
                        icon: const Icon(Icons.call_outlined),
                      ),

                    if (isAdmin && whatsapp.isNotEmpty)
                      IconButton(
                        onPressed: () => _openWhatsApp(whatsapp),
                        icon: const Icon(Icons.chat_outlined),
                      ),

                    if (isAdmin && locationUrl.isNotEmpty)
                      IconButton(
                        onPressed: () => _openLocation(locationUrl),
                        icon: const Icon(Icons.location_on_outlined),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.instance.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                        'فشل تحميل الرسائل: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                      child: Text('ابدأ أول رسالة الآن'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final senderId =
                        (data['senderId'] ?? '').toString();
                    final text = (data['text'] ?? '').toString();
                    final isMe = senderId == currentUserId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                                  0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : Colors.grey.shade800,
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(
                                  data['createdAt']),
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
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isSending ? null : _send,
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                                    strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}