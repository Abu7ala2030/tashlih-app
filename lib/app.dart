import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/route_generator.dart';
import 'routes/app_routes.dart';

class TashlihApp extends StatelessWidget {
  const TashlihApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tashlih App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
