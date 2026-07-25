import 'ludo_enums.dart';

class Pawn {
  final int id;
  final PlayerColor color;
  int step; // 0 = in base, 1..51 = main track, 52..56 = home path (56 = home finish)
  PawnState state;

  Pawn({
    required this.id,
    required this.color,
    this.step = 0,
    this.state = PawnState.inBase,
  });

  bool get isInBase => state == PawnState.inBase;
  bool get isFinished => state == PawnState.finished;
  bool get isOnTrack => state == PawnState.onTrack;
  bool get isInHomePath => state == PawnState.inHomePath;

  void reset() {
    step = 0;
    state = PawnState.inBase;
  }

  Pawn copyWith({
    int? step,
    PawnState? state,
  }) {
    return Pawn(
      id: id,
      color: color,
      step: step ?? this.step,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.index,
      'step': step,
      'state': state.index,
    };
  }

  factory Pawn.fromJson(Map<String, dynamic> json) {
    return Pawn(
      id: json['id'] as int,
      color: PlayerColor.values[json['color'] as int],
      step: json['step'] as int,
      state: PawnState.values[json['state'] as int],
    );
  }
}
