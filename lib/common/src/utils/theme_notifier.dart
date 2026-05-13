import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  factory ThemeNotifier() => _instance;
  ThemeNotifier._internal();
  static final ThemeNotifier _instance = ThemeNotifier._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
    }
  }
}
