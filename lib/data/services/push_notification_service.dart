import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/services/notification_navigation_service.dart';
import 'firestore_paths.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
  );

  String? _lastSavedToken;
  bool _listenersRegistered = false;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    await _requestPermission();
    await _setupForegroundPresentation();
    await _initializeLocalNotifications();
    _registerMessageListeners();
    _listenTokenRefresh();
    await syncCurrentUserToken();
  }

  void _registerMessageListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleNotificationData(message.data);
    });

    _messaging.getInitialMessage().then((message) async {
      if (message != null) {
        await _handleNotificationData(message.data);
      }
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            await _handleNotificationData(decoded);
          } else if (decoded is Map) {
            await _handleNotificationData(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (e) {
          debugPrint('Failed to parse notification payload: $e');
        }
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = (notification?.title ?? data['title'] ?? 'New notification')
        .toString()
        .trim();
    final body = (notification?.body ?? data['body'] ?? '').toString().trim();

    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final payload = jsonEncode(Map<String, dynamic>.from(data));

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      title,
      body.isEmpty ? null : body,
      details,
      payload: payload,
    );
  }

  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    await NotificationNavigationService.instance.handleNotification(data);
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

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      _lastSavedToken = token;
      final uid = currentUserId;
      if (uid == null || uid.isEmpty) return;
      await _saveToken(uid, token);
    });
  }

  Future<void> syncCurrentUserToken() async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    _lastSavedToken = token;
    await _saveToken(uid, token);
  }

  Future<void> removeCurrentDeviceToken({String? uid}) async {
    final userId = uid ?? currentUserId;
    if (userId == null || userId.isEmpty) return;

    String? token = _lastSavedToken;
    token ??= await _messaging.getToken();

    if (token == null || token.isEmpty) return;

    await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('deviceTokens')
        .doc(token)
        .delete()
        .catchError((_) {});

    if (_lastSavedToken == token) {
      _lastSavedToken = null;
    }
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