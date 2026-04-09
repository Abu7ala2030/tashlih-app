import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(String languageCode) {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    notifyListeners();
  }
}