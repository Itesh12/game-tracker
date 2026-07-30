import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/app_themes.dart';

class PlayerPanel extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final LudoThemeColors themeColors;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    final Color playerColor = themeColors.getPlayerColor(player.color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? playerColor.withOpacity(0.2)
            : themeColors.cardBg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? playerColor : themeColors.gridLine,
          width: isCurrentTurn ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isCurrentTurn)
            BoxShadow(
              color: playerColor.withOpacity(0.3),
              blurRadius: 8,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Color Avatar Circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: playerColor,
              border: Border.all(color: Colors.white, width: 1.5),
              image: player.photoUrl != null && player.photoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(player.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                ? Icon(
                    player.isBot ? Icons.smart_toy : Icons.person,
                    size: 18,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 8),

          // Player Name & Finish Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCurrentTurn
                      ? playerColor
                      : themeColors.textPrimary,
                ),
              ),
              Row(
                children: List.generate(4, (index) {
                  final isFinished = index < player.finishedPawnCount;
                  return Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: Icon(
                      isFinished ? Icons.stars : Icons.radio_button_unchecked,
                      size: 12,
                      color: isFinished ? Colors.amber : themeColors.textSecondary,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
