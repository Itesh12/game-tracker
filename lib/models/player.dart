import 'ludo_enums.dart';
import 'pawn.dart';

class Player {
  final PlayerColor color;
  String name;
  String? photoUrl;
  final bool isBot;
  final List<Pawn> pawns;
  int? rank; // 1, 2, 3, 4 when finished
  bool isActiveInGame; // Is this color playing in current session

  Player({
    required this.color,
    required this.name,
    this.photoUrl,
    this.isBot = false,
    this.isActiveInGame = true,
    List<Pawn>? pawns,
    this.rank,
  }) : pawns = pawns ??
            List.generate(4, (index) => Pawn(id: index, color: color));

  bool get hasWon => pawns.every((p) => p.isFinished);
  int get finishedPawnCount => pawns.where((p) => p.isFinished).length;

  void reset() {
    rank = null;
    for (var pawn in pawns) {
      pawn.reset();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.index,
      'name': name,
      'photoUrl': photoUrl,
      'isBot': isBot,
      'isActiveInGame': isActiveInGame,
      'rank': rank,
      'pawns': pawns.map((p) => p.toJson()).toList(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      color: PlayerColor.values[json['color'] as int],
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      isBot: json['isBot'] as bool? ?? false,
      isActiveInGame: json['isActiveInGame'] as bool? ?? true,
      rank: json['rank'] as int?,
      pawns: (json['pawns'] as List<dynamic>?)
              ?.map((p) => Pawn.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
