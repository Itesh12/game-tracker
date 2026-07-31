import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/logic/ludo_path_provider.dart';
import 'package:game_tracker/models/ludo_enums.dart';

void main() {
  group('LudoPathProvider Board Track & Position Tests', () {
    test('Outer track has exactly 52 coordinate tiles', () {
      expect(LudoPathProvider.outerTrack.length, 52);
    });

    test('Start track index mapping per color', () {
      expect(LudoPathProvider.getStartTrackIndex(PlayerColor.red), 0);
      expect(LudoPathProvider.getStartTrackIndex(PlayerColor.green), 13);
      expect(LudoPathProvider.getStartTrackIndex(PlayerColor.yellow), 26);
      expect(LudoPathProvider.getStartTrackIndex(PlayerColor.blue), 39);
    });

    test('Pawn coordinates at step 0 are inside home base offsets', () {
      for (final color in PlayerColor.values) {
        for (int p = 0; p < 4; p++) {
          final coord = LudoPathProvider.getPawnCoordinates(color, 0, p);
          expect(coord.x, greaterThanOrEqualTo(0.0));
          expect(coord.y, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('Pawn coordinates at step 1 match starting tile for each color', () {
      final redStart = LudoPathProvider.getPawnCoordinates(PlayerColor.red, 1, 0);
      expect(redStart.x, 6.0);
      expect(redStart.y, 1.0);

      final greenStart = LudoPathProvider.getPawnCoordinates(PlayerColor.green, 1, 0);
      expect(greenStart.x, 1.0);
      expect(greenStart.y, 8.0);

      final yellowStart = LudoPathProvider.getPawnCoordinates(PlayerColor.yellow, 1, 0);
      expect(yellowStart.x, 8.0);
      expect(yellowStart.y, 13.0);

      final blueStart = LudoPathProvider.getPawnCoordinates(PlayerColor.blue, 1, 0);
      expect(blueStart.x, 13.0);
      expect(blueStart.y, 6.0);
    });

    test('Pawn coordinates at home step 57 center triangle', () {
      for (final color in PlayerColor.values) {
        final homeCoord = LudoPathProvider.getPawnCoordinates(color, 57, 0);
        expect(homeCoord.x, greaterThan(6.0));
        expect(homeCoord.x, lessThan(8.0));
        expect(homeCoord.y, greaterThan(6.0));
        expect(homeCoord.y, lessThan(8.0));
      }
    });

    test('Star safe tiles identification', () {
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[0]), isTrue);  // Red Start
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[8]), isTrue);  // Star
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[13]), isTrue); // Green Start
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[21]), isTrue); // Star
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[26]), isTrue); // Yellow Start
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[34]), isTrue); // Star
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[39]), isTrue); // Blue Start
      expect(LudoPathProvider.isSafeTile(LudoPathProvider.outerTrack[47]), isTrue); // Star
    });
  });
}
