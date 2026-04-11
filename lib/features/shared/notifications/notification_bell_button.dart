import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/services/firestore_paths.dart';
import 'notifications_screen.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  bool _isPriorityType(String type) {
    return type == 'offer_accepted' ||
        type == 'request_shipped' ||
        type == 'request_delivered';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return IconButton(
        onPressed: null,
        icon: const Icon(Icons.notifications_none),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs.length;
        final priorityUnreadCount = docs.where((doc) {
          final type = (doc.data()['type'] ?? '').toString();
          return _isPriorityType(type);
        }).length;

        final hasUnread = unreadCount > 0;
        final hasPriorityUnread = priorityUnreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      initialType: hasPriorityUnread ? 'priority' : 'all',
                    ),
                  ),
                );
              },
              icon: Icon(
                hasPriorityUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                color: hasPriorityUnread ? Colors.redAccent : null,
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasPriorityUnread ? Colors.red : Colors.blueGrey,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            if (hasPriorityUnread)
              Positioned(
                left: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(.55),
                    ),
                  ),
                  child: Text(
                    priorityUnreadCount > 9
                        ? '${l10n.translate('important')} 9+'
                        : '${l10n.translate('important')} $priorityUnreadCount',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}