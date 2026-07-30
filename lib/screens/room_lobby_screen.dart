import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/ludo_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/game_room_model.dart';
import '../models/ludo_enums.dart';
import '../services/online_multiplayer_service.dart';
import 'game_screen.dart';

class RoomLobbyScreen extends StatelessWidget {
  const RoomLobbyScreen({
    super.key,
    required this.roomCode,
    required this.currentUid,
  });

  final String roomCode;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;

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
          child: StreamBuilder<GameRoom?>(
            stream: OnlineMultiplayerService.streamRoom(roomCode),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading room: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final room = snapshot.data;
              if (room == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Get.back();
                  Get.snackbar(
                    'Room Closed',
                    'The room was closed by the host.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                });
                return const SizedBox.shrink();
              }

              // Auto-navigate to GameScreen when host starts the game!
              if (room.status == 'playing') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ludoCtrl = Get.find<LudoController>();
                  ludoCtrl.startOnlineGameSession(room: room, currentUid: currentUid);
                  Get.off(() => const GameScreen());
                });
              }

              final isHost = room.hostId == currentUid;
              final canStart = isHost && room.players.length >= 2;

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
                          onPressed: () => _confirmLeave(context, isHost),
                        ),
                        Text(
                          'GAME LOBBY',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Invite Code Card
                    Card(
                      color: theme.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: theme.gridLine.withOpacity(0.4)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text(
                              'ROOM INVITE CODE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  room.roomCode,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                    color: theme.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.blueAccent),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: room.roomCode));
                                    Get.snackbar(
                                      'Code Copied!',
                                      'Invite code ${room.roomCode} copied to clipboard.',
                                      snackPosition: SnackPosition.TOP,
                                      duration: const Duration(seconds: 2),
                                    );
                                  },
                                  tooltip: 'Copy Invite Code',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Share this code with your friends to join!',
                              style: TextStyle(fontSize: 12, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Joined Players Count Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Players Joined (${room.players.length}/${room.maxPlayers})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: canStart ? Colors.green.shade600 : Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            canStart
                                ? 'Ready to Start!'
                                : room.players.length < 2
                                    ? 'Min 2 Required'
                                    : 'Waiting for players...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Player Slots Grid (4 slots)
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: room.maxPlayers,
                        itemBuilder: (context, index) {
                          final slotColor = _getSlotColor(index);
                          final hasPlayer = index < room.players.length;
                          final player = hasPlayer ? room.players[index] : null;

                          return Card(
                            color: theme.cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: hasPlayer ? slotColor : theme.gridLine.withOpacity(0.3),
                                width: hasPlayer ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: hasPlayer ? slotColor : Colors.grey.shade800,
                                    child: Icon(
                                      hasPlayer ? Icons.person : Icons.person_outline,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    hasPlayer ? player!.name : 'Slot ${index + 1} Open',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: hasPlayer ? theme.textPrimary : theme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (hasPlayer) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: slotColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        player!.isHost ? '👑 HOST' : _getColorName(player.colorIndex),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: slotColor,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      'Waiting...',
                                      style: TextStyle(fontSize: 11, color: theme.textSecondary.withOpacity(0.7)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Host / Player Action Buttons
                    if (isHost) ...[
                      ElevatedButton.icon(
                        onPressed: canStart
                            ? () async {
                                try {
                                  await OnlineMultiplayerService.startGame(roomCode);
                                } catch (e) {
                                  Get.snackbar(
                                    'Cannot Start Game',
                                    e.toString(),
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.redAccent,
                                    colorText: Colors.white,
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(
                          canStart ? 'START GAME NOW' : 'WAITING FOR 2+ PLAYERS',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canStart ? Colors.green.shade600 : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Waiting for host to start game...',
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getSlotColor(int index) {
    switch (index) {
      case 0:
        return Colors.redAccent;
      case 1:
        return Colors.green;
      case 2:
        return Colors.amber.shade700;
      case 3:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getColorName(int index) {
    switch (index) {
      case 0:
        return 'RED';
      case 1:
        return 'GREEN';
      case 2:
        return 'YELLOW';
      case 3:
        return 'BLUE';
      default:
        return '';
    }
  }

  void _confirmLeave(BuildContext context, bool isHost) {
    Get.dialog(
      AlertDialog(
        title: Text(isHost ? 'Close Room?' : 'Leave Room?'),
        content: Text(
          isHost
              ? 'Leaving will close the room for all joined players.'
              : 'Are you sure you want to leave this game lobby?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await OnlineMultiplayerService.leaveRoom(roomCode, currentUid);
              Get.back();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isHost ? 'Close Room' : 'Leave'),
          ),
        ],
      ),
    );
  }
}
