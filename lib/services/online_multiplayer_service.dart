import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_room_model.dart';

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
  }) async {
    String roomCode = generate6DigitCode();
    int attempts = 0;

    while (attempts < 5) {
      final doc = await _firestore.collection(roomCollection).doc(roomCode).get();
      if (!doc.exists) break;
      roomCode = generate6DigitCode();
      attempts++;
    }

    final hostPlayer = GameRoomPlayer(
      uid: hostUid,
      name: hostName.isEmpty ? 'Host' : hostName,
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

    await _firestore.collection(roomCollection).doc(roomCode).set(newRoom.toJson());
    return roomCode;
  }

  static Future<GameRoom?> getRoom(String roomCode) async {
    final doc = await _firestore.collection(roomCollection).doc(roomCode).get();
    if (!doc.exists) return null;
    return GameRoom.fromSnapshot(doc);
  }

  static Stream<GameRoom?> streamRoom(String roomCode) {
    return _firestore
        .collection(roomCollection)
        .doc(roomCode)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return GameRoom.fromSnapshot(snapshot);
    });
  }

  static Future<bool> joinRoom({
    required String roomCode,
    required String playerName,
    required String playerUid,
  }) async {
    final roomDocRef = _firestore.collection(roomCollection).doc(roomCode);
    final snapshot = await roomDocRef.get();

    if (!snapshot.exists) {
      throw 'Room $roomCode does not exist.';
    }

    final room = GameRoom.fromSnapshot(snapshot);

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
      colorIndex: nextColorIndex,
      isHost: false,
    );

    final updatedPlayers = [...room.players, newPlayer];

    await roomDocRef.update({
      'players': updatedPlayers.map((p) => p.toJson()).toList(),
    });

    return true;
  }

  static Future<void> startGame(String roomCode) async {
    final roomDocRef = _firestore.collection(roomCollection).doc(roomCode);
    final snapshot = await roomDocRef.get();
    if (!snapshot.exists) return;

    final room = GameRoom.fromSnapshot(snapshot);
    if (room.players.length < 2) {
      throw 'At least 2 players are required to start the game.';
    }

    await roomDocRef.update({
      'status': 'playing',
      'currentTurnIndex': 0,
      'diceValue': 1,
      'isDiceRolled': false,
      'isMoving': false,
      'consecutiveSixes': 0,
    });
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
        await _firestore.collection(roomCollection).doc(roomCode).update(data);
      }
    } catch (e) {
      debugPrint('Error syncing online move: $e');
    }
  }

  static Future<void> leaveRoom(String roomCode, String playerUid) async {
    try {
      final roomDocRef = _firestore.collection(roomCollection).doc(roomCode);
      final snapshot = await roomDocRef.get();
      if (!snapshot.exists) return;

      final room = GameRoom.fromSnapshot(snapshot);
      final updatedPlayers = room.players.where((p) => p.uid != playerUid).toList();

      if (updatedPlayers.isEmpty || room.hostId == playerUid) {
        // Delete room if host leaves or room becomes empty
        await roomDocRef.delete();
      } else {
        await roomDocRef.update({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
        });
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }
}
