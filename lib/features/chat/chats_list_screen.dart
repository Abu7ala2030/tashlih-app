import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

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

  String _formatChatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${date.day}/${date.month}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream(
    String uid,
    String role,
  ) {
    final chats = FirebaseFirestore.instance.collection('chats');

    if (role == 'worker') {
      return chats
          .where('workerId', isEqualTo: uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots();
    }

    if (role == 'customer') {
      return chats
          .where('customerId', isEqualTo: uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots();
    }

    return chats.orderBy('lastMessageAt', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.uid ?? '';
    final role = auth.safeRole;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        title: const Text(
          'المحادثات',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: uid.isEmpty
          ? const Center(
              child: Text(
                'لا يوجد مستخدم مسجل',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatsStream(uid, role),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatSnapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'فشل تحميل المحادثات:\n${chatSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                    ),
                  );
                }

                final chatDocs = chatSnapshot.data?.docs ?? [];

                if (chatDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد محادثات حتى الآن',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: chatDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chatDoc = chatDocs[index];
                    final chat = chatDoc.data();

                    final chatId = chatDoc.id;
                    final requestId = (chat['requestId'] ?? '').toString().trim();
                    final customerId =
                        (chat['customerId'] ?? '').toString().trim();
                    final workerId = (chat['workerId'] ?? '').toString().trim();
                    final lastMessage =
                        (chat['lastMessage'] ?? '').toString().trim();
                    final lastMessageAt = chat['lastMessageAt'];

                    final otherUserId = uid == customerId ? workerId : customerId;

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data?.data() ?? {};
                        final otherName =
                            (user['name'] ?? 'مستخدم').toString().trim();

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('requests')
                              .doc(requestId)
                              .snapshots(),
                          builder: (context, requestSnapshot) {
                            final request = requestSnapshot.data?.data() ?? {};
                            final partName =
                                (request['partName'] ?? 'طلب بدون اسم')
                                    .toString()
                                    .trim();
                            final vehicleMake =
                                (request['vehicleMake'] ?? '').toString().trim();
                            final vehicleModel =
                                (request['vehicleModel'] ?? '').toString().trim();
                            final vehicleYear =
                                (request['vehicleYear'] ?? '').toString().trim();
                            final city =
                                (request['city'] ?? '').toString().trim();
                            final status =
                                (request['status'] ?? '').toString().trim();

                            final vehicle =
                                '$vehicleMake $vehicleModel $vehicleYear'.trim();
                            final statusColor = _statusColor(status);
                            final unreadCount = uid == customerId
                                ? (chat['customerUnreadCount'] ?? 0)
                                : (chat['workerUnreadCount'] ?? 0);

                            final title = '$otherName • $partName';

                            return Material(
                              color: const Color(0xFF1A1D21),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        chatId: chatId,
                                        title: title,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                Colors.white10,
                                            child: Text(
                                              otherName.isEmpty
                                                  ? '?'
                                                  : otherName[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  otherName.isEmpty
                                                      ? 'مستخدم'
                                                      : otherName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  partName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatChatTime(lastMessageAt),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              if ((unreadCount is num) &&
                                                  unreadCount > 0) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    unreadCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _InfoChip(
                                            icon: Icons.tag_outlined,
                                            text:
                                                'طلب #${_requestShortId(requestId)}',
                                          ),
                                          if (city.isNotEmpty)
                                            _InfoChip(
                                              icon:
                                                  Icons.location_city_outlined,
                                              text: city,
                                            ),
                                          if (vehicle.isNotEmpty)
                                            _InfoChip(
                                              icon: Icons
                                                  .directions_car_outlined,
                                              text: vehicle,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                  0.16),
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              lastMessage.isEmpty
                                                  ? 'لا توجد رسائل بعد'
                                                  : lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
