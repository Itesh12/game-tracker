import 'package:cloud_firestore/cloud_firestore.dart';

class GameRoomPlayer {
  final String uid;
  final String name;
  final int colorIndex;
  final bool isHost;

  GameRoomPlayer({
    required this.uid,
    required this.name,
    required this.colorIndex,
    this.isHost = false,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'colorIndex': colorIndex,
        'isHost': isHost,
      };

  factory GameRoomPlayer.fromJson(Map<String, dynamic> json) => GameRoomPlayer(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? 'Player',
        colorIndex: json['colorIndex'] as int? ?? 0,
        isHost: json['isHost'] as bool? ?? false,
      );
}

class GameRoom {
  final String roomCode;
  final String hostId;
  final String hostName;
  final int maxPlayers;
  final String status; // 'lobby', 'playing', 'finished'
  final List<GameRoomPlayer> players;
  final int currentTurnIndex;
  final int diceValue;
  final bool isDiceRolled;
  final bool isMoving;
  final int consecutiveSixes;
  final DateTime? createdAt;
  final Map<String, dynamic>? gameStateData;

  GameRoom({
    required this.roomCode,
    required this.hostId,
    required this.hostName,
    required this.maxPlayers,
    required this.status,
    required this.players,
    this.currentTurnIndex = 0,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.isMoving = false,
    this.consecutiveSixes = 0,
    this.createdAt,
    this.gameStateData,
  });

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'hostId': hostId,
        'hostName': hostName,
        'maxPlayers': maxPlayers,
        'status': status,
        'players': players.map((p) => p.toJson()).toList(),
        'currentTurnIndex': currentTurnIndex,
        'diceValue': diceValue,
        'isDiceRolled': isDiceRolled,
        'isMoving': isMoving,
        'consecutiveSixes': consecutiveSixes,
        'createdAt': FieldValue.serverTimestamp(),
        if (gameStateData != null) 'gameStateData': gameStateData,
      };

  factory GameRoom.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final playerList = (data['players'] as List<dynamic>?)
            ?.map((p) => GameRoomPlayer.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return GameRoom(
      roomCode: snapshot.id,
      hostId: data['hostId'] as String? ?? '',
      hostName: data['hostName'] as String? ?? 'Host',
      maxPlayers: data['maxPlayers'] as int? ?? 4,
      status: data['status'] as String? ?? 'lobby',
      players: playerList,
      currentTurnIndex: data['currentTurnIndex'] as int? ?? 0,
      diceValue: data['diceValue'] as int? ?? 1,
      isDiceRolled: data['isDiceRolled'] as bool? ?? false,
      isMoving: data['isMoving'] as bool? ?? false,
      consecutiveSixes: data['consecutiveSixes'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      gameStateData: data['gameStateData'] as Map<String, dynamic>?,
    );
  }
}
