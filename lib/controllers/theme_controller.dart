import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/ludo_enums.dart';
import '../theme/app_themes.dart';

class ThemeController extends GetxController {
  final _appThemeMode = AppThemeMode.modernDark.obs;
  final _isDarkMode = true.obs;

  AppThemeMode get appThemeMode => _appThemeMode.value;
  bool get isDarkMode => _isDarkMode.value;

  LudoThemeColors get currentTheme {
    if (!_isDarkMode.value && _appThemeMode.value == AppThemeMode.modernDark) {
      return LudoThemeColors.classicLight;
    }

    switch (_appThemeMode.value) {
      case AppThemeMode.modernDark:
        return LudoThemeColors.modernDark;
      case AppThemeMode.classicLight:
        return LudoThemeColors.classicLight;
      case AppThemeMode.neonCyber:
        return LudoThemeColors.neonCyber;
      case AppThemeMode.royalGold:
        return LudoThemeColors.royalGold;
    }
  }

  void setThemeMode(AppThemeMode mode) {
    _appThemeMode.value = mode;
    if (mode == AppThemeMode.classicLight) {
      _isDarkMode.value = false;
    } else {
      _isDarkMode.value = true;
    }
    update();
  }

  void toggleDarkMode() {
    _isDarkMode.value = !_isDarkMode.value;
    if (!_isDarkMode.value && _appThemeMode.value == AppThemeMode.modernDark) {
      _appThemeMode.value = AppThemeMode.classicLight;
    } else if (_isDarkMode.value && _appThemeMode.value == AppThemeMode.classicLight) {
      _appThemeMode.value = AppThemeMode.modernDark;
    }
    update();
  }

  ThemeData get themeData {
    final colors = currentTheme;
    return ThemeData(
      brightness: _isDarkMode.value ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.bgGradient.first,
      cardColor: colors.cardBg,
      primaryColor: colors.blue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.blue,
        brightness: _isDarkMode.value ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
    );
  }
}
