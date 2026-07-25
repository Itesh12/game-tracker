import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ludo_controller.dart';
import '../controllers/theme_controller.dart';

class WinnerDialog extends StatelessWidget {
  const WinnerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final ludoCtrl = Get.find<LudoController>();
    final themeCtrl = Get.find<ThemeController>();
    final theme = themeCtrl.currentTheme;

    final winners = ludoCtrl.winners;
    final winner = winners.isNotEmpty ? winners.first : ludoCtrl.players.first;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy Icon with Glow
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 64,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'VICTORY!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${winner.name} won the game!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),

            // Podium Leaderboard
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.boardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.gridLine),
              ),
              child: Column(
                children: List.generate(winners.length, (index) {
                  final p = winners[index];
                  final color = theme.getPlayerColor(p.color);
                  final rankIcons = ['🥇', '🥈', '🥉', '4️⃣'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              rankIcons[index],
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rank #${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                      Get.back(); // Go to HomeScreen
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: theme.gridLine),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Main Menu',
                      style: TextStyle(color: theme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      ludoCtrl.startNewGame();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Play Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
