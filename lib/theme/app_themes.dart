import 'package:flutter/material.dart';
import '../models/ludo_enums.dart';

class LudoThemeColors {
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color boardBg;
  final Color gridLine;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color safeStar;
  final List<Color> bgGradient;

  const LudoThemeColors({
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.boardBg,
    required this.gridLine,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.safeStar,
    required this.bgGradient,
  });

  static const modernDark = LudoThemeColors(
    red: Color(0xFFFF4D4D),
    green: Color(0xFF2ECC71),
    yellow: Color(0xFFFFC107),
    blue: Color(0xFF3498DB),
    boardBg: Color(0xFF1E1E2E),
    gridLine: Color(0xFF313244),
    cardBg: Color(0xFF181825),
    textPrimary: Color(0xFFCDD6F4),
    textSecondary: Color(0xFFA6ADC8),
    safeStar: Color(0xFFFFD700),
    bgGradient: [Color(0xFF0F0C20), Color(0xFF1A1B35)],
  );

  static const classicLight = LudoThemeColors(
    red: Color(0xFFE74C3C),
    green: Color(0xFF27AE60),
    yellow: Color(0xFFF39C12),
    blue: Color(0xFF2980B9),
    boardBg: Color(0xFFFFFFFF),
    gridLine: Color(0xFFE0E0E0),
    cardBg: Color(0xFFF5F5F5),
    textPrimary: Color(0xFF2C3E50),
    textSecondary: Color(0xFF7F8C8D),
    safeStar: Color(0xFFF1C40F),
    bgGradient: [Color(0xFFEBF4F6), Color(0xFFD4E6F1)],
  );

  static const neonCyber = LudoThemeColors(
    red: Color(0xFFFF0055),
    green: Color(0xFF00FFCC),
    yellow: Color(0xFFFFEE00),
    blue: Color(0xFF0099FF),
    boardBg: Color(0xFF080811),
    gridLine: Color(0xFF1F1F3D),
    cardBg: Color(0xFF111122),
    textPrimary: Color(0xFF00FFCC),
    textSecondary: Color(0xFF8888AA),
    safeStar: Color(0xFFFFEE00),
    bgGradient: [Color(0xFF05050D), Color(0xFF120826)],
  );

  static const royalGold = LudoThemeColors(
    red: Color(0xFFC0392B),
    green: Color(0xFF1E8449),
    yellow: Color(0xFFD4AC0D),
    blue: Color(0xFF1B4F72),
    boardBg: Color(0xFF2C1D11),
    gridLine: Color(0xFF4A3525),
    cardBg: Color(0xFF3B2719),
    textPrimary: Color(0xFFF7DC6F),
    textSecondary: Color(0xFFB9935A),
    safeStar: Color(0xFFF1C40F),
    bgGradient: [Color(0xFF1C1008), Color(0xFF321F13)],
  );

  Color getPlayerColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return red;
      case PlayerColor.green:
        return green;
      case PlayerColor.yellow:
        return yellow;
      case PlayerColor.blue:
        return blue;
    }
  }
}
