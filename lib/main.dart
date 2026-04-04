import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/notification_navigation_service.dart';
import 'core/theme/app_theme.dart';
import 'data/services/push_notification_service.dart';
import 'features/session/session_gate.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/request_provider.dart';
import 'providers/vehicle_provider.dart';
import 'routes/route_generator.dart';

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

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await PushNotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        navigatorKey: NotificationNavigationService.instance.navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Tashlih App',
        theme: AppTheme.darkTheme,
        home: const SessionGate(),
        onGenerateRoute: RouteGenerator.generateRoute,
      ),
    );
  }
}
