import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/models/ludo_enums.dart';
import 'package:game_tracker/models/pawn.dart';
import 'package:game_tracker/models/player.dart';

void main() {
  group('Comprehensive Ludo Pawn & Player Game Logic Tests', () {
    test('Pawn initial state and base unlocking rules', () {
      final pawn = Pawn(id: 0, color: PlayerColor.red);
      expect(pawn.isInBase, isTrue);
      expect(pawn.step, equals(0));
      expect(pawn.isFinished, isFalse);

      pawn.step = 1;
      pawn.state = PawnState.onTrack;
      expect(pawn.isInBase, isFalse);
      expect(pawn.isOnTrack, isTrue);
      expect(pawn.step, equals(1));
    });

    test('Pawn track progression and home path handling', () {
      final pawn = Pawn(id: 1, color: PlayerColor.green);
      pawn.step = 1;
      pawn.state = PawnState.onTrack;

      // Advance by 10 steps
      pawn.step += 10;
      expect(pawn.step, equals(11));

      // Home path transition
      pawn.step = 52;
      pawn.state = PawnState.inHomePath;
      expect(pawn.isInHomePath, isTrue);

      // Finish at step 56
      pawn.step = 56;
      pawn.state = PawnState.finished;
      expect(pawn.isFinished, isTrue);
    });

    test('Pawn cut and reset to base', () {
      final pawn = Pawn(id: 2, color: PlayerColor.yellow);
      pawn.step = 15;
      pawn.state = PawnState.onTrack;
      expect(pawn.isInBase, isFalse);

      pawn.reset();
      expect(pawn.step, equals(0));
      expect(pawn.isInBase, isTrue);
      expect(pawn.isFinished, isFalse);
    });

    test('Player victory detection when all 4 pawns finish', () {
      final player = Player(color: PlayerColor.blue, name: 'Champion');
      expect(player.hasWon, isFalse);

      // Finish pawns one by one
      player.pawns[0].state = PawnState.finished;
      player.pawns[1].state = PawnState.finished;
      player.pawns[2].state = PawnState.finished;
      expect(player.hasWon, isFalse);
      expect(player.finishedPawnCount, equals(3));

      player.pawns[3].state = PawnState.finished;
      expect(player.hasWon, isTrue);
      expect(player.finishedPawnCount, equals(4));
    });

    test('Player reset state restores all 4 pawns to base and clears rank', () {
      final player = Player(color: PlayerColor.red, name: 'Red Player');
      player.rank = 1;
      for (final p in player.pawns) {
        p.state = PawnState.finished;
        p.step = 56;
      }
      expect(player.hasWon, isTrue);

      player.reset();
      expect(player.rank, isNull);
      expect(player.hasWon, isFalse);
      for (final p in player.pawns) {
        expect(p.isInBase, isTrue);
        expect(p.step, equals(0));
      }
    });
  });
}
