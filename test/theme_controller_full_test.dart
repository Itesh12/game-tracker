import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/models/ludo_enums.dart';
import 'package:game_tracker/theme/app_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController & ThemePalette Tests', () {
    test('AppThemeMode enumeration and properties', () {
      expect(AppThemeMode.values.length, equals(4));
      expect(AppThemeMode.classicLight.name, equals('classicLight'));
      expect(AppThemeMode.neonCyber.name, equals('neonCyber'));
      expect(AppThemeMode.royalGold.name, equals('royalGold'));
      expect(AppThemeMode.modernDark.name, equals('modernDark'));
    });

    test('LudoThemeColors palette configurations', () {
      expect(LudoThemeColors.modernDark.boardBg, isNotNull);
      expect(LudoThemeColors.classicLight.boardBg, isNotNull);
      expect(LudoThemeColors.neonCyber.boardBg, isNotNull);
      expect(LudoThemeColors.royalGold.boardBg, isNotNull);
    });
  });
}
