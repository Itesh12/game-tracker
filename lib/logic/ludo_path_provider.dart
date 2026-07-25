import '../models/ludo_enums.dart';

class LudoPathProvider {
  // 52 main outer track tiles in clockwise sequence (row, col)
  static final List<Point<int>> outerTrack = const [
    Point(6, 1),   // 0: Red Start
    Point(6, 2),   // 1
    Point(6, 3),   // 2
    Point(6, 4),   // 3
    Point(6, 5),   // 4
    Point(5, 6),   // 5
    Point(4, 6),   // 6
    Point(3, 6),   // 7
    Point(2, 6),   // 8: Green Safe Star
    Point(1, 6),   // 9
    Point(0, 6),   // 10
    Point(0, 7),   // 11
    Point(0, 8),   // 12
    Point(1, 8),   // 13: Green Start
    Point(2, 8),   // 14
    Point(3, 8),   // 15
    Point(4, 8),   // 16
    Point(5, 8),   // 17
    Point(6, 9),   // 18
    Point(6, 10),  // 19
    Point(6, 11),  // 20
    Point(6, 12),  // 21: Yellow Safe Star
    Point(6, 13),  // 22
    Point(6, 14),  // 23
    Point(7, 14),  // 24
    Point(8, 14),  // 25
    Point(8, 13),  // 26: Yellow Start
    Point(8, 12),  // 27
    Point(8, 11),  // 28
    Point(8, 10),  // 29
    Point(8, 9),   // 30
    Point(9, 8),   // 31
    Point(10, 8),  // 32
    Point(11, 8),  // 33
    Point(12, 8),  // 34: Blue Safe Star
    Point(13, 8),  // 35
    Point(14, 8),  // 36
    Point(14, 7),  // 37
    Point(14, 6),  // 38
    Point(13, 6),  // 39: Blue Start
    Point(12, 6),  // 40
    Point(11, 6),  // 41
    Point(10, 6),  // 42
    Point(9, 6),   // 43
    Point(8, 5),   // 44
    Point(8, 4),   // 45
    Point(8, 3),   // 46
    Point(8, 2),   // 47: Red Safe Star
    Point(8, 1),   // 48
    Point(8, 0),   // 49
    Point(7, 0),   // 50
    Point(6, 0),   // 51
  ];

  // Base inner positions for pawns inside home bases (row, col)
  // Inside 4x4 inner box of 6x6 base, the 4 slot centers are at offsets 2.0 and 4.0!
  static Point<double> getBasePawnOffset(PlayerColor color, int pawnId) {
    switch (color) {
      case PlayerColor.red:
        final coords = [
          const Point(2.0, 2.0),
          const Point(2.0, 4.0),
          const Point(4.0, 2.0),
          const Point(4.0, 4.0),
        ];
        return coords[pawnId % 4];
      case PlayerColor.green:
        final coords = [
          const Point(2.0, 11.0),
          const Point(2.0, 13.0),
          const Point(4.0, 11.0),
          const Point(4.0, 13.0),
        ];
        return coords[pawnId % 4];
      case PlayerColor.yellow:
        final coords = [
          const Point(11.0, 11.0),
          const Point(11.0, 13.0),
          const Point(13.0, 11.0),
          const Point(13.0, 13.0),
        ];
        return coords[pawnId % 4];
      case PlayerColor.blue:
        final coords = [
          const Point(11.0, 2.0),
          const Point(11.0, 4.0),
          const Point(13.0, 2.0),
          const Point(13.0, 4.0),
        ];
        return coords[pawnId % 4];
    }
  }

  // Get outer track starting index for each color
  static int getStartTrackIndex(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return 0;
      case PlayerColor.green:
        return 13;
      case PlayerColor.yellow:
        return 26;
      case PlayerColor.blue:
        return 39;
    }
  }

  // Get tile safe status (4 Start tiles + 4 Safe Star tiles = 8 safe spots)
  static bool isSafeTile(Point<int> point) {
    const safePoints = [
      Point(6, 1),   // Red Start
      Point(1, 8),   // Green Start
      Point(8, 13),  // Yellow Start
      Point(13, 6),  // Blue Start
      Point(8, 2),   // Red Star
      Point(2, 6),   // Green Star
      Point(6, 12),  // Yellow Star
      Point(12, 8),  // Blue Star
    ];
    return safePoints.contains(point);
  }

  // Get exact grid coordinates for a given player color and step number (0..57)
  static Point<double> getPawnCoordinates(PlayerColor color, int step, int pawnId) {
    // Step 0: In base
    if (step == 0) {
      return getBasePawnOffset(color, pawnId);
    }

    // Step 57: In center Home triangle
    if (step >= 57) {
      switch (color) {
        case PlayerColor.red:
          return const Point(7.0, 6.2);
        case PlayerColor.green:
          return const Point(6.2, 7.0);
        case PlayerColor.yellow:
          return const Point(7.0, 7.8);
        case PlayerColor.blue:
          return const Point(7.8, 7.0);
      }
    }

    // Step 1..51: On outer track
    if (step <= 51) {
      final startIndex = getStartTrackIndex(color);
      final trackIndex = (startIndex + (step - 1)) % 52;
      final point = outerTrack[trackIndex];
      return Point(point.x.toDouble(), point.y.toDouble());
    }

    // Step 52..56: Home stretch path
    final homeStep = step - 51; // 1 to 5
    switch (color) {
      case PlayerColor.red:
        return Point(7.0, homeStep.toDouble());
      case PlayerColor.green:
        return Point(homeStep.toDouble(), 7.0);
      case PlayerColor.yellow:
        return Point(7.0, (14 - homeStep).toDouble());
      case PlayerColor.blue:
        return Point((14 - homeStep).toDouble(), 7.0);
    }
  }
}

class Point<T extends num> {
  final T x; // row index in grid
  final T y; // col index in grid

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}
