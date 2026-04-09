import 'package:flutter/material.dart';

class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({
    super.key,
    required this.child,
  });

  static const BoxDecoration _backgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFF0F1012),
        Color(0xFF15181C),
        Color(0xFF0F1012),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _backgroundDecoration,
      child: RepaintBoundary(child: child),
    );
  }
}
