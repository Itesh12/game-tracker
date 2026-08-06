import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ludo_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/pawn.dart';
import '../models/ludo_enums.dart';
import '../logic/ludo_path_provider.dart';
import '../widgets/ludo_board_painter.dart';
import '../widgets/pawn_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/player_panel.dart';
import '../widgets/theme_selector_sheet.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return GetBuilder<ThemeController>(
      builder: (tCtrl) {
        final theme = tCtrl.currentTheme;

        return GetBuilder<LudoController>(
          builder: (gameCtrl) {
            return Scaffold(
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: theme.bgGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top Action Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                _showExitConfirmation(context, gameCtrl, theme);
                              },
                              icon: Icon(Icons.arrow_back_ios, color: theme.textPrimary),
                              tooltip: 'Exit Game',
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => gameCtrl.toggleSound(),
                                  icon: Icon(
                                    gameCtrl.soundEnabled
                                        ? Icons.volume_up
                                        : Icons.volume_off,
                                    color: theme.textPrimary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Get.bottomSheet(
                                      const ThemeSelectorSheet(),
                                      isScrollControlled: true,
                                    );
                                  },
                                  icon: Icon(Icons.palette_outlined, color: theme.textPrimary),
                                ),
                                IconButton(
                                  onPressed: () => gameCtrl.startNewGame(),
                                  icon: Icon(Icons.refresh, color: theme.textPrimary),
                                  tooltip: 'Restart Game',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Top Player Panels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (gameCtrl.players.isNotEmpty)
                              PlayerPanel(
                                player: gameCtrl.players[0],
                                isCurrentTurn: gameCtrl.currentTurnIndex == 0,
                                themeColors: theme,
                              ),
                            if (gameCtrl.players.length >= 2)
                              PlayerPanel(
                                player: gameCtrl.players[1],
                                isCurrentTurn: gameCtrl.currentTurnIndex == 1,
                                themeColors: theme,
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Center Board Area
                      Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double boardSize =
                                (constraints.maxWidth - 24).clamp(280.0, 480.0);
                            final double tileSize = boardSize / 15.0;

                            return Container(
                              width: boardSize,
                              height: boardSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // 1. Board Painter Graphics
                                  CustomPaint(
                                    size: Size(boardSize, boardSize),
                                    painter: LudoBoardPainter(themeColors: theme),
                                  ),

                                  // 2. Render Pawns
                                  ..._buildPawnOverlay(gameCtrl, tileSize, theme),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Spacer(),

                      // Turn Status Banner
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.gridLine),
                        ),
                        child: Text(
                          _getTurnStatusMessage(gameCtrl),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.getPlayerColor(gameCtrl.currentPlayer.color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bottom Player Panels & Center Dice Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bottom-Left Player
                            if (gameCtrl.players.length >= 4)
                              PlayerPanel(
                                player: gameCtrl.players[3],
                                isCurrentTurn: gameCtrl.currentTurnIndex == 3,
                                themeColors: theme,
                              )
                            else
                              const SizedBox(width: 80),

                            // Animated Interactive Dice Widget
                            DiceWidget(
                              value: gameCtrl.diceValue,
                              isRolling: gameCtrl.isDiceRolling,
                              isRolled: gameCtrl.isDiceRolled,
                              isCurrentTurn: true,
                              isBot: gameCtrl.currentPlayer.isBot,
                              playerColor: gameCtrl.currentPlayer.color,
                              themeColors: theme,
                              onTap: () => gameCtrl.rollDice(),
                            ),

                            // Bottom-Right Player
                            if (gameCtrl.players.length >= 3)
                              PlayerPanel(
                                player: gameCtrl.players[2],
                                isCurrentTurn: gameCtrl.currentTurnIndex == 2,
                                themeColors: theme,
                              )
                            else
                              const SizedBox(width: 80),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildPawnOverlay(
      LudoController gameCtrl, double tileSize, dynamic theme) {
    List<Widget> pawnWidgets = [];

    // Group pawns by step position to handle stacking offsets
    Map<String, List<Pawn>> tileOccupants = {};

    for (var player in gameCtrl.players) {
      for (var pawn in player.pawns) {
        if (pawn.isOnTrack) {
          final coords = LudoPathProvider.getPawnCoordinates(
              pawn.color, pawn.step, pawn.id);
          final key = '${coords.x.round()}_${coords.y.round()}';
          tileOccupants.putIfAbsent(key, () => []).add(pawn);
        }
      }
    }

    for (var player in gameCtrl.players) {
      for (var pawn in player.pawns) {
        final isTurn = player.color == gameCtrl.currentPlayer.color;
        final isMovable = isTurn && gameCtrl.movablePawns.contains(pawn);
        final isSelected = gameCtrl.selectedPawn == pawn;

        int stackIndex = 0;
        int stackCount = 1;

        if (pawn.isOnTrack) {
          final coords = LudoPathProvider.getPawnCoordinates(
              pawn.color, pawn.step, pawn.id);
          final key = '${coords.x.round()}_${coords.y.round()}';
          final list = tileOccupants[key] ?? [];
          stackIndex = list.indexOf(pawn);
          stackCount = list.length;
        }

        pawnWidgets.add(
          PawnWidget(
            key: ValueKey('pawn_${pawn.color.name}_${pawn.id}'),
            pawn: pawn,
            tileSize: tileSize,
            themeColors: theme,
            isSelectable: isMovable && !player.isBot,
            isSelected: isSelected,
            stackIndex: stackIndex,
            stackCount: stackCount,
            onTap: () {
              gameCtrl.movePawn(pawn);
            },
          ),
        );
      }
    }

    return pawnWidgets;
  }

  String _getTurnStatusMessage(LudoController gameCtrl) {
    if (gameCtrl.isDiceRolling) {
      return 'Rolling dice...';
    }
    if (gameCtrl.isMoving) {
      return 'Moving token...';
    }
    if (gameCtrl.currentPlayer.isBot) {
      return '${gameCtrl.currentPlayer.name} (Computer) is taking turn...';
    }
    if (!gameCtrl.isDiceRolled) {
      return '${gameCtrl.currentPlayer.name}\'s turn! Tap dice to roll.';
    }
    if (gameCtrl.movablePawns.isEmpty) {
      return 'No valid moves available!';
    }
    return '${gameCtrl.currentPlayer.name}: Tap a glowing token to move!';
  }

  void _showExitConfirmation(
      BuildContext context, LudoController gameCtrl, dynamic theme) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardBg,
        title: Text(
          'Exit Game?',
          style: TextStyle(color: theme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to leave the current game?',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
