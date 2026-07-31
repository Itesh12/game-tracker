import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/models/ludo_enums.dart';
import 'package:game_tracker/theme/app_themes.dart';

void main() {
  group('LudoThemeColors & Theme Preset Palette Tests', () {
    test('modernDark palette color definitions', () {
      const theme = LudoThemeColors.modernDark;
      expect(theme.boardBg, const Color(0xFF1E1E2E));
      expect(theme.cardBg, const Color(0xFF181825));
      expect(theme.safeStar, const Color(0xFFFFD700));
      expect(theme.bgGradient.length, 2);
    });

    test('classicLight palette color definitions', () {
      const theme = LudoThemeColors.classicLight;
      expect(theme.boardBg, const Color(0xFFFFFFFF));
      expect(theme.cardBg, const Color(0xFFF5F5F5));
      expect(theme.textPrimary, const Color(0xFF2C3E50));
    });

    test('neonCyber palette color definitions', () {
      const theme = LudoThemeColors.neonCyber;
      expect(theme.boardBg, const Color(0xFF080811));
      expect(theme.textPrimary, const Color(0xFF00FFCC));
    });

    test('royalGold palette color definitions', () {
      const theme = LudoThemeColors.royalGold;
      expect(theme.boardBg, const Color(0xFF2C1D11));
      expect(theme.textPrimary, const Color(0xFFF7DC6F));
    });

    test('getPlayerColor maps all 4 PlayerColors to distinct colors', () {
      const theme = LudoThemeColors.modernDark;
      final redColor = theme.getPlayerColor(PlayerColor.red);
      final greenColor = theme.getPlayerColor(PlayerColor.green);
      final yellowColor = theme.getPlayerColor(PlayerColor.yellow);
      final blueColor = theme.getPlayerColor(PlayerColor.blue);

      expect(redColor, theme.red);
      expect(greenColor, theme.green);
      expect(yellowColor, theme.yellow);
      expect(blueColor, theme.blue);
      expect(redColor != greenColor, isTrue);
      expect(greenColor != yellowColor, isTrue);
      expect(yellowColor != blueColor, isTrue);
    });
  });
}
