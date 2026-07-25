enum PlayerColor {
  red,
  green,
  yellow,
  blue,
}

enum PawnState {
  inBase,
  onTrack,
  inHomePath,
  finished,
}

enum GameMode {
  passAndPlay,
  vsComputer,
}

enum GameStateStatus {
  setup,
  playing,
  paused,
  gameOver,
}

enum AppThemeMode {
  modernDark,
  classicLight,
  neonCyber,
  royalGold,
}

extension PlayerColorExtension on PlayerColor {
  String get name {
    switch (this) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }
}
