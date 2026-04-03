import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_paths.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _db.collection(FirestorePaths.chats);

  Future<String> createOrGetChat({
    required String requestId,
    required String customerId,
    required String workerId,
  }) async {
    final existing = await _chatsRef
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      final existingData = existingDoc.data();

      final hasParticipants =
          existingData['participants'] is List &&
          (existingData['participants'] as List).isNotEmpty;

      final hasUnreadCount = existingData['unreadCount'] is Map;

      if (!hasParticipants || !hasUnreadCount) {
        await existingDoc.reference.set({
          'requestId': requestId,
          'customerId': customerId,
          'workerId': workerId,
          'participants': [customerId, workerId],
          'unreadCount': {
            'customer': 0,
            'worker': 0,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));
      }

      return existingDoc.id;
    }

    final doc = _chatsRef.doc();

    await doc.set({
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'participants': [customerId, workerId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'unreadCount': {
        'customer': 0,
        'worker': 0,
      },
    });

    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyChats() {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _chatsRef
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
    required String senderRole,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw Exception('لا يوجد مستخدم مسجل');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('الرسالة فارغة');
    }

    final chatRef = _chatsRef.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      throw Exception('المحادثة غير موجودة');
    }

    final chatData = chatSnap.data() ?? <String, dynamic>{};

    final participants = (chatData['participants'] is List)
        ? List<String>.from(chatData['participants'])
        : <String>[];

    if (!participants.contains(uid)) {
      throw Exception('غير مصرح لك بإرسال رسالة في هذه المحادثة');
    }

    final receiverRole = senderRole == 'customer' ? 'worker' : 'customer';

    final batch = _db.batch();

    batch.set(messageRef, {
      'senderId': uid,
      'senderRole': senderRole,
      'text': trimmed,
      'type': 'text',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': {
        'customer': (chatData['unreadCount']?['customer'] ?? 0),
        'worker': (chatData['unreadCount']?['worker'] ?? 0),
      },
      'unreadCount.$receiverRole': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String role,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    final chatRef = _chatsRef.doc(chatId);
    final chatSnap = await chatRef.get();

    if (!chatSnap.exists) return;

    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final participants = (chatData['participants'] is List)
        ? List<String>.from(chatData['participants'])
        : <String>[];

    if (!participants.contains(uid)) return;

    final unread = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();

    for (final doc in unread.docs) {
      final data = doc.data();
      if ((data['senderId'] ?? '') != uid) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }
    }

    batch.set(chatRef, {
      'unreadCount.$role': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> ensureChatExists({
    required String chatId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final doc = _chatsRef.doc(chatId);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'unreadCount': {
          'customer': 0,
          'worker': 0,
        },
      }, SetOptions(merge: true));
      return;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final hasParticipants =
        data['participants'] is List && (data['participants'] as List).isNotEmpty;
    final hasUnreadCount = data['unreadCount'] is Map;

    if (!hasParticipants || !hasUnreadCount) {
      await doc.set({
        'participants': [currentUserId, otherUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'unreadCount': {
          'customer': 0,
          'worker': 0,
        },
      }, SetOptions(merge: true));
    }
  }
}