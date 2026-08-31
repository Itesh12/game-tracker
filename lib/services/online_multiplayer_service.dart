import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_room_model.dart';
import 'backend_bridge_service.dart';

class OnlineMultiplayerService {
  OnlineMultiplayerService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String roomCollection = 'game_rooms';

  static String generate6DigitCode() {
    final rand = Random();
    final code = 100000 + rand.nextInt(900000);
    return code.toString();
  }

  static Future<String> createRoom({
    required int maxPlayers,
    required String hostName,
    required String hostUid,
    String? hostPhotoUrl,
  }) async {
    String roomCode = generate6DigitCode();
    int attempts = 0;

    while (attempts < 5) {
      final existing = await getRoom(roomCode);
      if (existing == null) break;
      roomCode = generate6DigitCode();
      attempts++;
    }

    final hostPlayer = GameRoomPlayer(
      uid: hostUid,
      name: hostName.isEmpty ? 'Host' : hostName,
      photoUrl: hostPhotoUrl,
      colorIndex: 0,
      isHost: true,
    );

    final newRoom = GameRoom(
      roomCode: roomCode,
      hostId: hostUid,
      hostName: hostName.isEmpty ? 'Host' : hostName,
      maxPlayers: maxPlayers,
      status: 'lobby',
      players: [hostPlayer],
    );

    await BackendBridgeService.saveLudoRoomData(roomCode, newRoom.toJson());
    return roomCode;
  }

  static Future<GameRoom?> getRoom(String roomCode) async {
    try {
      final doc = await _firestore.collection(roomCollection).doc(roomCode).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        return GameRoom.fromSnapshot(doc);
      }
    } catch (_) {}

    if (BackendBridgeService.isSupabaseReady) {
      try {
        final res = await BackendBridgeService.supabase!.from('ludo_rooms').select().eq('room_code', roomCode).maybeSingle();
        if (res != null) {
          return GameRoom.fromJson(res);
        }
      } catch (_) {}
    }
    return null;
  }

  static Stream<GameRoom?> streamRoom(String roomCode) {
    late final StreamController<GameRoom?> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? supabaseSub;

    controller = StreamController<GameRoom?>.broadcast(
      onListen: () {
        try {
          firestoreSub = _firestore
              .collection(roomCollection)
              .doc(roomCode)
              .snapshots()
              .listen((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              controller.add(GameRoom.fromSnapshot(snapshot));
            }
          }, onError: (_) {});
        } catch (_) {}

        if (BackendBridgeService.isSupabaseReady) {
          try {
            supabaseSub = BackendBridgeService.supabase!
                .from('ludo_rooms')
                .stream(primaryKey: ['id'])
                .eq('room_code', roomCode)
                .listen((rows) {
              if (rows.isNotEmpty) {
                controller.add(GameRoom.fromJson(rows.first));
              }
            }, onError: (_) {});
          } catch (_) {}
        }
      },
      onCancel: () {
        firestoreSub?.cancel();
        supabaseSub?.cancel();
      },
    );

    return controller.stream;
  }

  static Future<bool> joinRoom({
    required String roomCode,
    required String playerName,
    required String playerUid,
    String? photoUrl,
  }) async {
    final room = await getRoom(roomCode);

    if (room == null) {
      throw 'Room $roomCode does not exist.';
    }

    if (room.status != 'lobby') {
      throw 'Game in room $roomCode has already started.';
    }

    if (room.players.any((p) => p.uid == playerUid)) {
      // Already joined
      return true;
    }

    if (room.players.length >= room.maxPlayers) {
      throw 'Room $roomCode is full (Max ${room.maxPlayers} players).';
    }

    // Determine unused color index (0..3)
    final usedColors = room.players.map((p) => p.colorIndex).toSet();
    int nextColorIndex = 0;
    for (int i = 0; i < 4; i++) {
      if (!usedColors.contains(i)) {
        nextColorIndex = i;
        break;
      }
    }

    final newPlayer = GameRoomPlayer(
      uid: playerUid,
      name: playerName.isEmpty ? 'Player ${room.players.length + 1}' : playerName,
      photoUrl: photoUrl,
      colorIndex: nextColorIndex,
      isHost: false,
    );

    final updatedPlayers = [...room.players, newPlayer];

    final updateData = {
      'players': updatedPlayers.map((p) => p.toJson()).toList(),
    };
    try {
      await _firestore.collection(roomCollection).doc(roomCode).update(updateData);
    } catch (_) {}
    await BackendBridgeService.saveLudoRoomData(roomCode, updateData);

    return true;
  }

  static Future<void> startGame(String roomCode) async {
    final room = await getRoom(roomCode);
    if (room == null) return;

    if (room.players.length < 2) {
      throw 'At least 2 players are required to start the game.';
    }

    final gameStartData = {
      'status': 'playing',
      'currentTurnIndex': 0,
      'diceValue': 1,
      'isDiceRolled': false,
      'isMoving': false,
      'consecutiveSixes': 0,
    };

    try {
      await _firestore.collection(roomCollection).doc(roomCode).update(gameStartData);
    } catch (_) {}
    await BackendBridgeService.saveLudoRoomData(roomCode, gameStartData);
  }

  static Future<void> updateGameAction(
    String roomCode, {
    int? currentTurnIndex,
    int? diceValue,
    bool? isDiceRolled,
    bool? isMoving,
    int? consecutiveSixes,
    Map<String, dynamic>? gameStateData,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (currentTurnIndex != null) data['currentTurnIndex'] = currentTurnIndex;
      if (diceValue != null) data['diceValue'] = diceValue;
      if (isDiceRolled != null) data['isDiceRolled'] = isDiceRolled;
      if (isMoving != null) data['isMoving'] = isMoving;
      if (consecutiveSixes != null) data['consecutiveSixes'] = consecutiveSixes;
      if (gameStateData != null) data['gameStateData'] = gameStateData;

      if (data.isNotEmpty) {
        try {
          await _firestore.collection(roomCollection).doc(roomCode).update(data);
        } catch (_) {}
        await BackendBridgeService.saveLudoRoomData(roomCode, data);
      }
    } catch (e) {
      debugPrint('Error syncing online move: $e');
    }
  }

  static Future<void> leaveRoom(String roomCode, String playerUid) async {
    try {
      final room = await getRoom(roomCode);
      if (room == null) return;

      final updatedPlayers = room.players.where((p) => p.uid != playerUid).toList();

      if (updatedPlayers.isEmpty || room.hostId == playerUid) {
        // Delete room if host leaves or room becomes empty
        try {
          await _firestore.collection(roomCollection).doc(roomCode).delete();
        } catch (_) {}
        await BackendBridgeService.saveLudoRoomData(roomCode, {'status': 'deleted'});
      } else {
        final updateData = {
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
        };
        try {
          await _firestore.collection(roomCollection).doc(roomCode).update(updateData);
        } catch (_) {}
        await BackendBridgeService.saveLudoRoomData(roomCode, updateData);
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }
}
