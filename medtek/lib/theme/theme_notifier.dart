import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _prefKey = 'themeMode';
  ThemeMode _mode = ThemeMode.system;

  ThemeNotifier._();

  ThemeMode get mode => _mode;

  static Future<ThemeNotifier> create() async {
    final t = ThemeNotifier._();
    await t._load();
    return t;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefKey) ?? 'system';
      _mode = _fromString(s);
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _toString(m));
    } catch (_) {}
  }

  void toggleTheme() {
    if (_mode == ThemeMode.dark) {
      setMode(ThemeMode.light);
    } else {
      setMode(ThemeMode.dark);
    }
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
