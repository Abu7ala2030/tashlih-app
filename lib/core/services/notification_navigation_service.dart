import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/services/firestore_paths.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/customer/requests/customer_request_offers_screen.dart';
import '../../features/customer/requests/customer_request_tracking_screen.dart';
import '../../features/driver/requests/driver_request_details_screen.dart';

class NotificationNavigationService {
  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  NotificationNavigationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> handleNotification(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString().trim();
    final chatId = (data['chatId'] ?? '').toString().trim();
    final requestId = (data['requestId'] ?? '').toString().trim();

    switch (type) {
      case 'new_offer':
        await _openOffers(data, requestId: requestId);
        return;

      case 'request_accepted':
      case 'request_shipped':
      case 'request_delivered':
      case 'driver_assigned_customer':
        await _openTracking(data, requestId: requestId);
        return;

      case 'driver_assigned':
        await _openDriverRequestDetails(data, requestId: requestId);
        return;

      case 'chat_message':
      case 'new_message':
        _openChat(chatId);
        return;

      default:
        if (chatId.isNotEmpty) {
          _openChat(chatId);
          return;
        }

        if (requestId.isNotEmpty) {
          await _openTracking(data, requestId: requestId);
        }
    }
  }

  Future<void> _openOffers(
    Map<String, dynamic> data, {
    required String requestId,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final request = await _resolveRequest(data, requestId: requestId);
    if (request == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CustomerRequestOffersScreen(
          request: request,
        ),
      ),
    );
  }

  Future<void> _openTracking(
    Map<String, dynamic> data, {
    required String requestId,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final request = await _resolveRequest(data, requestId: requestId);
    if (request == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CustomerRequestTrackingScreen(
          request: request,
        ),
      ),
    );
  }

  Future<void> _openDriverRequestDetails(
    Map<String, dynamic> data, {
    required String requestId,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final request = await _resolveRequest(data, requestId: requestId);
    if (request == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => DriverRequestDetailsScreen(
          request: request,
        ),
      ),
    );
  }

  void _openChat(String chatId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null || chatId.isEmpty) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: 'Chat',
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _resolveRequest(
    Map<String, dynamic> data, {
    required String requestId,
  }) async {
    final embeddedRequest = data['request'];
    if (embeddedRequest is Map<String, dynamic>) {
      return embeddedRequest;
    }

    if (embeddedRequest is Map) {
      return Map<String, dynamic>.from(embeddedRequest);
    }

    if (requestId.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();

    if (!doc.exists) return null;

    final request = doc.data() ?? <String, dynamic>{};
    request['id'] = doc.id;
    return request;
  }
}