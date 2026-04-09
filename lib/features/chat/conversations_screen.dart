import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/services/chat_service.dart';

class ConversationsScreen extends StatelessWidget {
  final String senderRole;

  const ConversationsScreen({super.key, required this.senderRole});

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
      appBar: AppBar(title: const Text('المحادثات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ChatService.instance.streamMyChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('فشل تحميل المحادثات: ${snapshot.error}'),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(child: Text('لا توجد محادثات بعد'));
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = chats[index];
              final data = doc.data();

              final customerId = (data['customerId'] ?? '').toString();
              //final workerId = (data['workerId'] ?? '').toString();
              final requestId = (data['requestId'] ?? '').toString();
              final lastMessage = (data['lastMessage'] ?? '').toString();

              final title = currentUserId == customerId ? 'العامل' : 'العميل';

              final subtitle = lastMessage.isNotEmpty
                  ? lastMessage
                  : 'محادثة الطلب #$requestId';
              final unreadMap = data['unreadCount'] ?? {};
              final unread = unreadMap[senderRole] ?? 0;

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.chat_bubble_outline),
                ),
                title: Text(title),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_formatTime(data['lastMessageAt'])),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
