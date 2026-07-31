import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/models/ludo_enums.dart';
import 'package:game_tracker/models/pawn.dart';
import 'package:game_tracker/models/player.dart';

void main() {
  group('Pawn Data Model & State Transitions', () {
    test('Initial pawn state is inBase at step 0', () {
      final pawn = Pawn(id: 0, color: PlayerColor.red);
      expect(pawn.id, 0);
      expect(pawn.color, PlayerColor.red);
      expect(pawn.step, 0);
      expect(pawn.state, PawnState.inBase);
      expect(pawn.isInBase, isTrue);
      expect(pawn.isOnTrack, isFalse);
      expect(pawn.isInHomePath, isFalse);
      expect(pawn.isFinished, isFalse);
    });

    test('Pawn state reset restores step 0 and inBase state', () {
      final pawn = Pawn(id: 1, color: PlayerColor.green, step: 25, state: PawnState.onTrack);
      pawn.reset();

      expect(pawn.step, 0);
      expect(pawn.state, PawnState.inBase);
      expect(pawn.isInBase, isTrue);
    });

    test('Pawn copyWith immutability update', () {
      final original = Pawn(id: 2, color: PlayerColor.blue, step: 10, state: PawnState.onTrack);
      final updated = original.copyWith(step: 15);

      expect(updated.id, original.id);
      expect(updated.color, original.color);
      expect(updated.step, 15);
      expect(updated.state, PawnState.onTrack);
      expect(original.step, 10);
    });

    test('Pawn JSON serialization & deserialization round-trip', () {
      final pawn = Pawn(id: 3, color: PlayerColor.yellow, step: 56, state: PawnState.finished);
      final json = pawn.toJson();

      expect(json['id'], 3);
      expect(json['color'], PlayerColor.yellow.index);
      expect(json['step'], 56);
      expect(json['state'], PawnState.finished.index);

      final deserialized = Pawn.fromJson(json);
      expect(deserialized.id, 3);
      expect(deserialized.color, PlayerColor.yellow);
      expect(deserialized.step, 56);
      expect(deserialized.state, PawnState.finished);
      expect(deserialized.isFinished, isTrue);
    });
  });

  group('Player Data Model & Victory Conditions', () {
    test('Player initialization defaults to 4 pawns inside base', () {
      final player = Player(color: PlayerColor.red, name: 'Alice');
      expect(player.color, PlayerColor.red);
      expect(player.name, 'Alice');
      expect(player.isBot, isFalse);
      expect(player.isActiveInGame, isTrue);
      expect(player.pawns.length, 4);
      expect(player.hasWon, isFalse);
      expect(player.finishedPawnCount, 0);
    });

    test('Player reset clears rank and resets all 4 pawns to base', () {
      final player = Player(color: PlayerColor.green, name: 'Bot 1', isBot: true, rank: 1);
      player.pawns[0].state = PawnState.finished;
      player.pawns[0].step = 56;

      expect(player.finishedPawnCount, 1);
      player.reset();

      expect(player.rank, isNull);
      expect(player.finishedPawnCount, 0);
      expect(player.hasWon, isFalse);
    });

    test('Player hasWon is true only when all 4 pawns are finished', () {
      final player = Player(color: PlayerColor.blue, name: 'Champion');
      expect(player.hasWon, isFalse);

      for (int i = 0; i < 3; i++) {
        player.pawns[i].state = PawnState.finished;
        player.pawns[i].step = 56;
      }
      expect(player.hasWon, isFalse); // Only 3 finished

      player.pawns[3].state = PawnState.finished;
      player.pawns[3].step = 56;
      expect(player.hasWon, isTrue); // All 4 finished
    });

    test('Player JSON serialization and deserialization round-trip', () {
      final player = Player(
        color: PlayerColor.yellow,
        name: 'SuperPlayer',
        photoUrl: 'https://example.com/avatar.jpg',
        isBot: true,
        rank: 2,
      );

      final json = player.toJson();
      expect(json['color'], PlayerColor.yellow.index);
      expect(json['name'], 'SuperPlayer');
      expect(json['photoUrl'], 'https://example.com/avatar.jpg');
      expect(json['isBot'], isTrue);
      expect(json['rank'], 2);

      final deserialized = Player.fromJson(json);
      expect(deserialized.color, PlayerColor.yellow);
      expect(deserialized.name, 'SuperPlayer');
      expect(deserialized.photoUrl, 'https://example.com/avatar.jpg');
      expect(deserialized.isBot, isTrue);
      expect(deserialized.rank, 2);
    });
  });
}
