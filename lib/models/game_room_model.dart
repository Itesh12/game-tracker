import 'package:cloud_firestore/cloud_firestore.dart';

class GameRoomPlayer {
  final String uid;
  final String name;
  final String? photoUrl;
  final int colorIndex;
  final bool isHost;

  GameRoomPlayer({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.colorIndex,
    this.isHost = false,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'photoUrl': photoUrl,
        'colorIndex': colorIndex,
        'isHost': isHost,
      };

  factory GameRoomPlayer.fromJson(Map<String, dynamic> json) => GameRoomPlayer(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? 'Player',
        photoUrl: json['photoUrl'] as String?,
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

  factory GameRoom.fromJson(Map<String, dynamic> data) {
    final playerList = (data['players'] as List<dynamic>?)
            ?.map((p) => GameRoomPlayer.fromJson(p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p as Map)))
            .toList() ??
        [];

    DateTime? parsedCreatedAt;
    if (data['created_at'] != null) {
      if (data['created_at'] is Timestamp) {
        parsedCreatedAt = (data['created_at'] as Timestamp).toDate();
      } else if (data['created_at'] is String) {
        parsedCreatedAt = DateTime.tryParse(data['created_at'] as String);
      }
    } else if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        parsedCreatedAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(data['createdAt'] as String);
      }
    }

    return GameRoom(
      roomCode: data['room_code'] as String? ?? data['roomCode'] as String? ?? data['id'] as String? ?? '',
      hostId: data['host_uid'] as String? ?? data['hostId'] as String? ?? '',
      hostName: data['host_name'] as String? ?? data['hostName'] as String? ?? 'Host',
      maxPlayers: (data['max_players'] as num?)?.toInt() ?? (data['maxPlayers'] as num?)?.toInt() ?? 4,
      status: data['status'] as String? ?? 'lobby',
      players: playerList,
      currentTurnIndex: (data['current_turn_index'] as num?)?.toInt() ?? (data['currentTurnIndex'] as num?)?.toInt() ?? 0,
      diceValue: (data['dice_value'] as num?)?.toInt() ?? (data['diceValue'] as num?)?.toInt() ?? 1,
      isDiceRolled: data['is_dice_rolled'] as bool? ?? data['isDiceRolled'] as bool? ?? false,
      isMoving: data['is_moving'] as bool? ?? data['isMoving'] as bool? ?? false,
      consecutiveSixes: (data['consecutive_sixes'] as num?)?.toInt() ?? (data['consecutiveSixes'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
      gameStateData: data['game_state_data'] is Map ? Map<String, dynamic>.from(data['game_state_data'] as Map) : (data['gameStateData'] as Map<String, dynamic>?),
    );
  }
}
