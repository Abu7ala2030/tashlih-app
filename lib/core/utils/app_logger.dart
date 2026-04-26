import 'package:logger/logger.dart';

class AppLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  static void i(dynamic msg) => _logger.i(msg);
  static void e(dynamic msg) => _logger.e(msg);
  static void w(dynamic msg) => _logger.w(msg);
}