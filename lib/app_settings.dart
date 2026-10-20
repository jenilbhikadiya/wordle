import 'package:flutter/material.dart';

import 'data/storage.dart';

/// App-wide preferences that screens listen to.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  ThemeMode themeMode = ThemeMode.system;
  bool hardMode = false;

  Future<void> load() async {
    hardMode = await Storage.instance.hardMode();
    themeMode = switch (await Storage.instance.themeMode()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    Storage.instance.setThemeMode(mode.name);
    notifyListeners();
  }

  void setHardMode(bool value) {
    hardMode = value;
    Storage.instance.setHardMode(value);
    notifyListeners();
  }
}
