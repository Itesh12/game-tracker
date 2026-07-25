import 'package:flutter/material.dart';
import '../models/pawn.dart';
import '../theme/app_themes.dart';
import '../logic/ludo_path_provider.dart';

class PawnWidget extends StatelessWidget {
  final Pawn pawn;
  final double tileSize;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onTap;
  final LudoThemeColors themeColors;
  final int stackIndex;
  final int stackCount;

  const PawnWidget({
    super.key,
    required this.pawn,
    required this.tileSize,
    required this.themeColors,
    this.isSelectable = false,
    this.isSelected = false,
    this.onTap,
    this.stackIndex = 0,
    this.stackCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final coords = LudoPathProvider.getPawnCoordinates(
        pawn.color, pawn.step, pawn.id);

    double cx;
    double cy;
    double pawnSize;

    if (pawn.isInBase) {
      cx = coords.y * tileSize;
      cy = coords.x * tileSize;
      pawnSize = tileSize * 1.05;
    } else if (pawn.isFinished) {
      cx = coords.y * tileSize;
      cy = coords.x * tileSize;
      pawnSize = tileSize * 0.7;
    } else {
      cx = (coords.y + 0.5) * tileSize;
      cy = (coords.x + 0.5) * tileSize;
      pawnSize = tileSize * 0.75;
    }

    // Stack offset if multiple pawns share tile on track
    if (stackCount > 1 && pawn.isOnTrack) {
      final double offset = (tileSize * 0.18);
      cx += (stackIndex % 2) * offset - (offset / 2);
      cy += (stackIndex ~/ 2) * offset - (offset / 2);
    }

    final double left = cx - (pawnSize / 2);
    final double top = cy - (pawnSize / 2);

    final Color pawnColor = themeColors.getPlayerColor(pawn.color);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutBack,
      left: left,
      top: top,
      width: pawnSize,
      height: pawnSize,
      child: GestureDetector(
        onTap: isSelectable ? onTap : null,
        child: AnimatedScale(
          scale: isSelectable ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (isSelectable)
                  BoxShadow(
                    color: pawnColor.withOpacity(0.95),
                    blurRadius: 14.0,
                    spreadRadius: 4.0,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 6.0,
                    offset: const Offset(2, 4),
                  ),
              ],
            ),
            child: Stack(
              children: [
                // 1. Main 3D Sphere Body
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        pawnColor,
                        Color.lerp(pawnColor, Colors.black, 0.45)!,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      center: const Alignment(-0.3, -0.35),
                    ),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber
                          : (isSelectable ? Colors.white : Colors.white70),
                      width: isSelectable ? 2.5 : 1.5,
                    ),
                  ),
                ),

                // 2. Gloss Specular Reflection (Top Left Glass Shine)
                Positioned(
                  top: pawnSize * 0.1,
                  left: pawnSize * 0.18,
                  width: pawnSize * 0.35,
                  height: pawnSize * 0.22,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.7),
                          Colors.white.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // 3. Center Crown Jewel Cap
                Center(
                  child: Container(
                    width: pawnSize * 0.36,
                    height: pawnSize * 0.36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: pawnColor.withOpacity(0.8),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: pawnSize * 0.16,
                        height: pawnSize * 0.16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pawnColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
