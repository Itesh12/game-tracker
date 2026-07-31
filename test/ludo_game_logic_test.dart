import 'package:flutter_test/flutter_test.dart';

class TestPawn {
  final int id;
  final int colorIndex;
  int stepIndex;
  bool isHome;

  TestPawn({
    required this.id,
    required this.colorIndex,
    this.stepIndex = -1,
    this.isHome = false,
  });
}

class TestLudoGame {
  int currentTurnColor = 0; // 0: Red, 1: Green, 2: Yellow, 3: Blue
  final Map<int, List<TestPawn>> pawns = {};

  TestLudoGame() {
    for (int c = 0; c < 4; c++) {
      pawns[c] = List.generate(4, (i) => TestPawn(id: i, colorIndex: c));
    }
  }

  void nextTurn() {
    currentTurnColor = (currentTurnColor + 1) % 4;
  }

  bool canMovePawn(TestPawn pawn, int diceRoll) {
    if (pawn.isHome) return false;
    if (pawn.stepIndex == -1) {
      return diceRoll == 6;
    }
    return (pawn.stepIndex + diceRoll) <= 56;
  }

  void movePawn(TestPawn pawn, int diceRoll) {
    if (!canMovePawn(pawn, diceRoll)) return;
    if (pawn.stepIndex == -1 && diceRoll == 6) {
      pawn.stepIndex = 0;
    } else {
      pawn.stepIndex += diceRoll;
      if (pawn.stepIndex == 56) {
        pawn.isHome = true;
      }
    }
  }

  bool isPlayerWinner(int colorIndex) {
    final playerPawns = pawns[colorIndex];
    if (playerPawns == null) return false;
    return playerPawns.every((p) => p.isHome);
  }
}

void main() {
  group('Ludo Realm Engine & Rule Logic Tests', () {
    late TestLudoGame game;

    setUp(() {
      game = TestLudoGame();
    });

    test('Initial game setup has 4 players with 4 pawns each at base (-1)', () {
      expect(game.pawns.length, 4);
      for (int c = 0; c < 4; c++) {
        expect(game.pawns[c]!.length, 4);
        expect(game.pawns[c]!.every((p) => p.stepIndex == -1), isTrue);
        expect(game.pawns[c]!.every((p) => !p.isHome), isTrue);
      }
    });

    test('Turn progression moves cyclically: Red -> Green -> Yellow -> Blue -> Red', () {
      expect(game.currentTurnColor, 0); // Red
      game.nextTurn();
      expect(game.currentTurnColor, 1); // Green
      game.nextTurn();
      expect(game.currentTurnColor, 2); // Yellow
      game.nextTurn();
      expect(game.currentTurnColor, 3); // Blue
      game.nextTurn();
      expect(game.currentTurnColor, 0); // Red
    });

    test('Pawn cannot leave base without rolling a 6', () {
      final pawn = game.pawns[0]![0];
      expect(game.canMovePawn(pawn, 1), isFalse);
      expect(game.canMovePawn(pawn, 5), isFalse);
      expect(game.canMovePawn(pawn, 6), isTrue);

      game.movePawn(pawn, 6);
      expect(pawn.stepIndex, 0);
    });

    test('Pawn moves along track up to home stretch (56)', () {
      final pawn = game.pawns[0]![0];
      pawn.stepIndex = 50;

      expect(game.canMovePawn(pawn, 6), isTrue);
      expect(game.canMovePawn(pawn, 7), isFalse); // Exceeds 56

      game.movePawn(pawn, 6);
      expect(pawn.stepIndex, 56);
      expect(pawn.isHome, isTrue);
    });

    test('Player wins when all 4 pawns reach home (56)', () {
      expect(game.isPlayerWinner(0), isFalse);

      for (final p in game.pawns[0]!) {
        p.isHome = true;
        p.stepIndex = 56;
      }

      expect(game.isPlayerWinner(0), isTrue);
      expect(game.isPlayerWinner(1), isFalse);
    });
  });
}
