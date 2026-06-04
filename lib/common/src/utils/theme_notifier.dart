import 'package:cardwave/common/src/theme/theme_style_enum.dart';
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

  ThemeStyleEnum _themeStyle = ThemeStyleEnum.standard;
  ThemeStyleEnum get themeStyle => _themeStyle;

  set themeStyle(ThemeStyleEnum value) {
    if (_themeStyle != value) {
      _themeStyle = value;
      notifyListeners();
    }
  }
}
