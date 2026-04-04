import 'package:flutter/material.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/customer/requests/customer_request_offers_screen.dart';
import '../../features/customer/requests/customer_request_tracking_screen.dart';

class NotificationNavigationService {
  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  NotificationNavigationService._();

  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  void handleNotification(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'new_offer':
        _openOffers(data);
        break;

      case 'request_accepted':
      case 'request_shipped':
        _openTracking(data);
        break;

      case 'new_message':
        _openChat(data);
        break;
    }
  }

  void _openOffers(Map<String, dynamic> data) {
    final request = data['request'];

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CustomerRequestOffersScreen(
          request: request,
        ),
      ),
    );
  }

  void _openTracking(Map<String, dynamic> data) {
    final request = data['request'];

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CustomerRequestTrackingScreen(
          request: request,
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> data) {
    final chatId = data['chatId'];

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: 'المحادثة',
        ),
      ),
    );
  }
}