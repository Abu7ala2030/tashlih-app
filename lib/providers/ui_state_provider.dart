import 'package:flutter/material.dart';

class UIStateProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    error = value;
    notifyListeners();
  }

  void reset() {
    isLoading = false;
    error = null;
    notifyListeners();
  }
}
