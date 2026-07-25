import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ludo_enums.dart';
import '../theme/app_themes.dart';

class DiceWidget extends StatelessWidget {
  final int value;
  final bool isRolling;
  final bool isRolled;
  final bool isCurrentTurn;
  final bool isBot;
  final PlayerColor playerColor;
  final VoidCallback? onTap;
  final LudoThemeColors themeColors;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.isRolled,
    required this.isCurrentTurn,
    required this.isBot,
    required this.playerColor,
    required this.themeColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = themeColors.getPlayerColor(playerColor);

    return GestureDetector(
      onTap: (isCurrentTurn && !isRolled && !isRolling && !isBot) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: themeColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentTurn ? activeColor : themeColors.gridLine,
            width: isCurrentTurn ? 3.5 : 1.5,
          ),
          boxShadow: [
            if (isCurrentTurn)
              BoxShadow(
                color: activeColor.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isRolling)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pi * 4),
                duration: const Duration(milliseconds: 500),
                builder: (context, angle, child) {
                  return Transform.rotate(
                    angle: angle,
                    child: _buildDiceFace(value, activeColor),
                  );
                },
              )
            else
              _buildDiceFace(value, activeColor),

            if (isCurrentTurn && !isRolled && !isRolling && !isBot)
              Positioned(
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ROLL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceFace(int val, Color dotColor) {
    final List<bool> dots = List.filled(9, false);

    switch (val) {
      case 1:
        dots[4] = true;
        break;
      case 2:
        dots[0] = true;
        dots[8] = true;
        break;
      case 3:
        dots[0] = true;
        dots[4] = true;
        dots[8] = true;
        break;
      case 4:
        dots[0] = true;
        dots[2] = true;
        dots[6] = true;
        dots[8] = true;
        break;
      case 5:
        dots[0] = true;
        dots[2] = true;
        dots[4] = true;
        dots[6] = true;
        dots[8] = true;
        break;
      case 6:
        dots[0] = true;
        dots[2] = true;
        dots[3] = true;
        dots[5] = true;
        dots[6] = true;
        dots[8] = true;
        break;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        if (!dots[index]) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: [
              BoxShadow(
                color: dotColor.withOpacity(0.6),
                blurRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
