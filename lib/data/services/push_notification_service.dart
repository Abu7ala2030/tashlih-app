import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firestore_paths.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    await _requestPermission();
    await _setupForegroundPresentation();
    await _saveInitialToken();
    _listenTokenRefresh();
  }

  Future<void> bindForegroundListeners({
    required void Function(String chatId) onOpenChat,
    required void Function(String requestId) onOpenRequest,
  }) async {
    // 🔥 استقبال الإشعار داخل التطبيق (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null) {
        print('🔔 إشعار داخل التطبيق: ${notification.title}');
        print('📩 ${notification.body}');
      }
    });

    // 🔥 عند الضغط على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNavigation(message, onOpenChat, onOpenRequest);
    });

    // 🔥 إذا التطبيق كان مغلق وفتح من إشعار
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNavigation(initialMessage, onOpenChat, onOpenRequest);
    }
  }

  void _handleNavigation(
    RemoteMessage message,
    void Function(String chatId) onOpenChat,
    void Function(String requestId) onOpenRequest,
  ) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();

    if (type == 'chat_message') {
      final chatId = (data['chatId'] ?? '').toString();
      if (chatId.isNotEmpty) {
        onOpenChat(chatId);
      }
      return;
    }

    final requestId = (data['requestId'] ?? '').toString();
    if (requestId.isNotEmpty) {
      onOpenRequest(requestId);
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _setupForegroundPresentation() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _saveInitialToken() async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _saveToken(uid, token);
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      final uid = currentUserId;
      if (uid == null || uid.isEmpty) return;
      await _saveToken(uid, token);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('deviceTokens')
        .doc(token)
        .set({
          'token': token,
          'platform': Platform.isAndroid
              ? 'android'
              : (Platform.isIOS ? 'ios' : 'other'),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
