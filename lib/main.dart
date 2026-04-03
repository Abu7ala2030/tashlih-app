import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/push_notification_service.dart';
import 'features/chat/chat_screen.dart';
import 'features/auth/simple_login_screen.dart'; // ✅ جديد
import 'firebase_options.dart';
import 'providers/home_provider.dart';
import 'providers/request_provider.dart';
import 'providers/vehicle_provider.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
import 'providers/auth_provider.dart';
import 'features/session/session_gate.dart';
import '../features/customer/home/customer_home_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await PushNotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _listenersBound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_listenersBound) return;
    _listenersBound = true;

    PushNotificationService.instance.bindForegroundListeners(
      onOpenChat: (chatId) {
        final navigator = appNavigatorKey.currentState;
        if (navigator == null) return;

        navigator.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              title: 'المحادثة',
            ),
          ),
        );
      },
      onOpenRequest: (requestId) {
        final navigator = appNavigatorKey.currentState;
        if (navigator == null) return;

        navigator.pushNamed(
          '/request-tracking',
          arguments: requestId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Tashlih App',
        theme: AppTheme.darkTheme,

        // 🔥 أهم تغيير هنا
        home: const SessionGate(),

        // ❌ عطلنا البداية القديمة مؤقتًا
        // initialRoute: AppRoutes.splash,

        onGenerateRoute: RouteGenerator.generateRoute,
      ),
    );
  }
}