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

  int _readFlatCount(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  int _readNestedCount(Map<String, dynamic> chatData, String role) {
    final unread = chatData['unreadCount'];
    if (unread is Map && unread[role] is num) {
      return (unread[role] as num).toInt();
    }
    return 0;
  }

  Future<void> _syncChatCounters({
    required DocumentReference<Map<String, dynamic>> chatRef,
    required Map<String, dynamic> chatData,
  }) async {
    final customerUnreadFlat = _readFlatCount(chatData['customerUnreadCount']);
    final workerUnreadFlat = _readFlatCount(chatData['workerUnreadCount']);

    final customerUnreadNested = _readNestedCount(chatData, 'customer');
    final workerUnreadNested = _readNestedCount(chatData, 'worker');

    final customerUnread =
        customerUnreadFlat > customerUnreadNested
            ? customerUnreadFlat
            : customerUnreadNested;

    final workerUnread =
        workerUnreadFlat > workerUnreadNested
            ? workerUnreadFlat
            : workerUnreadNested;

    await chatRef.set({
      'customerUnreadCount': customerUnread,
      'workerUnreadCount': workerUnread,
      'unreadCount': {
        'customer': customerUnread,
        'worker': workerUnread,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
  }

  Future<String> createOrGetChat({
    required String requestId,
    required String customerId,
    required String workerId,
  }) async {
    final existing =
        await _chatsRef.where('requestId', isEqualTo: requestId).limit(1).get();

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      final existingData = existingDoc.data();

      final hasParticipants =
          existingData['participants'] is List &&
          (existingData['participants'] as List).isNotEmpty;

      final hasUnreadCount = existingData['unreadCount'] is Map;
      final hasFlatCounts =
          existingData.containsKey('customerUnreadCount') &&
          existingData.containsKey('workerUnreadCount');

      if (!hasParticipants || !hasUnreadCount || !hasFlatCounts) {
        await existingDoc.reference.set({
          'requestId': requestId,
          'customerId': customerId,
          'workerId': workerId,
          'participants': [customerId, workerId],
          'lastMessage': (existingData['lastMessage'] ?? '').toString(),
          'lastSenderId': (existingData['lastSenderId'] ?? '').toString(),
          'lastMessageAt':
              existingData['lastMessageAt'] ?? FieldValue.serverTimestamp(),
          'customerUnreadCount': _readFlatCount(
            existingData['customerUnreadCount'],
          ),
          'workerUnreadCount': _readFlatCount(
            existingData['workerUnreadCount'],
          ),
          'unreadCount': {
            'customer': _readNestedCount(existingData, 'customer'),
            'worker': _readNestedCount(existingData, 'worker'),
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));
      }

      await _syncChatCounters(
        chatRef: existingDoc.reference,
        chatData: existingDoc.data(),
      );

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
      'customerUnreadCount': 0,
      'workerUnreadCount': 0,
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

    return _chatsRef.where('participants', arrayContains: uid).snapshots();
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
      throw Exception('No authenticated user');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message is empty');
    }

    final chatRef = _chatsRef.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      throw Exception('Chat not found');
    }

    final chatData = chatSnap.data() ?? <String, dynamic>{};

    final participants =
        (chatData['participants'] is List)
            ? List<String>.from(chatData['participants'])
            : <String>[];

    if (!participants.contains(uid)) {
      throw Exception('You are not allowed to send messages in this chat');
    }

    final receiverRole = senderRole == 'customer' ? 'worker' : 'customer';

    final customerUnreadCurrent = _readFlatCount(chatData['customerUnreadCount']);
    final workerUnreadCurrent = _readFlatCount(chatData['workerUnreadCount']);

    final nextCustomerUnread =
        receiverRole == 'customer'
            ? customerUnreadCurrent + 1
            : customerUnreadCurrent;

    final nextWorkerUnread =
        receiverRole == 'worker'
            ? workerUnreadCurrent + 1
            : workerUnreadCurrent;

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
      'isActive': true,
      'customerUnreadCount': nextCustomerUnread,
      'workerUnreadCount': nextWorkerUnread,
      'unreadCount': {
        'customer': nextCustomerUnread,
        'worker': nextWorkerUnread,
      },
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
    final participants =
        (chatData['participants'] is List)
            ? List<String>.from(chatData['participants'])
            : <String>[];

    if (!participants.contains(uid)) return;

    final unread =
        await chatRef.collection('messages').where('isRead', isEqualTo: false).get();

    final batch = _db.batch();

    for (final doc in unread.docs) {
      final data = doc.data();
      if ((data['senderId'] ?? '') != uid) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }
    }

    final customerUnread =
        role == 'customer' ? 0 : _readFlatCount(chatData['customerUnreadCount']);
    final workerUnread =
        role == 'worker' ? 0 : _readFlatCount(chatData['workerUnreadCount']);

    batch.set(chatRef, {
      'customerUnreadCount': customerUnread,
      'workerUnreadCount': workerUnread,
      'unreadCount': {
        'customer': customerUnread,
        'worker': workerUnread,
      },
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
        'lastMessage': '',
        'lastSenderId': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'customerUnreadCount': 0,
        'workerUnreadCount': 0,
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
    final hasFlatCounts =
        data.containsKey('customerUnreadCount') &&
        data.containsKey('workerUnreadCount');

    if (!hasParticipants || !hasUnreadCount || !hasFlatCounts) {
      await doc.set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': (data['lastMessage'] ?? '').toString(),
        'lastSenderId': (data['lastSenderId'] ?? '').toString(),
        'lastMessageAt': data['lastMessageAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'customerUnreadCount': _readFlatCount(data['customerUnreadCount']),
        'workerUnreadCount': _readFlatCount(data['workerUnreadCount']),
        'unreadCount': {
          'customer': _readNestedCount(data, 'customer'),
          'worker': _readNestedCount(data, 'worker'),
        },
      }, SetOptions(merge: true));
    }

    await _syncChatCounters(
      chatRef: doc,
      chatData: data,
    );
  }
}