import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../services/admin_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/ludo_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/ludo_enums.dart';
import '../services/online_multiplayer_service.dart';
import '../services/permission_service.dart';
import '../widgets/theme_selector_sheet.dart';
import 'admin_panel_screen.dart';
import 'game_screen.dart';
import 'room_lobby_screen.dart';
import 'profile_screen.dart';
import '../services/android_screen_capture.dart';
import '../utils/app_alert.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  GameMode selectedMode = GameMode.vsComputer;
  int selectedPlayerCount = 4;
  final List<TextEditingController> nameControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
    TextEditingController(text: 'Player 4'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  void _checkPermissions() async {
    if (kIsWeb) return;
    final authCtrl = Get.find<AuthController>();
    if (!authCtrl.isAdmin) {
      if (!kIsWeb && Platform.isAndroid) {
        final screenCaptureGranted = await AndroidScreenCapture.hasPermission();
        if (!screenCaptureGranted) {
          final granted =
              await PermissionService.ensureScreenCapturePermission();
          if (granted) {
            await AdminService.registerDevice();
          }
        }
      }
      if (mounted) {
        PermissionService.checkAndEnforcePermissions(context);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ludoCtrl = Get.find<LudoController>();
    final authCtrl = Get.find<AuthController>();

    return GetBuilder<ThemeController>(
      builder: (ctrl) {
        final theme = ctrl.currentTheme;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar with Theme, Permissions, & Rules Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            Get.bottomSheet(
                              const ThemeSelectorSheet(),
                              isScrollControlled: true,
                            );
                          },
                          icon: Icon(
                            Icons.palette_outlined,
                            color: theme.textPrimary,
                            size: 28,
                          ),
                          tooltip: 'Customize Theme',
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                PermissionService.showMandatoryPermissionDialog(
                                  context,
                                  () {
                                    AppAlert.showSuccess(
                                      'All required permissions are active!',
                                      title: 'Permissions Granted',
                                    );
                                  },
                                );
                              },
                              icon: Icon(
                                Icons.security,
                                color: theme.blue,
                                size: 28,
                              ),
                              tooltip: 'Permissions Settings',
                            ),
                            IconButton(
                              onPressed: () => _showRulesDialog(context),
                              icon: Icon(
                                Icons.help_outline,
                                color: theme.textPrimary,
                                size: 28,
                              ),
                              tooltip: 'Game Rules',
                            ),
                            Obx(() {
                              if (!authCtrl.isSignedIn) {
                                return const SizedBox.shrink();
                              }
                              return Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Get.to(
                                      () => const ProfileScreen(),
                                    ),
                                    icon: Icon(
                                      Icons.account_circle,
                                      color: theme.blue,
                                      size: 28,
                                    ),
                                    tooltip: 'My Profile',
                                  ),
                                  if (authCtrl.isAdmin)
                                    IconButton(
                                      onPressed: () => Get.to(
                                        () => const AdminPanelScreen(),
                                      ),
                                      icon: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.amber,
                                        size: 28,
                                      ),
                                      tooltip: 'Admin Panel',
                                    ),
                                  IconButton(
                                    onPressed: () async {
                                      await authCtrl.signOut();
                                    },
                                    icon: Icon(
                                      Icons.logout,
                                      color: theme.textPrimary,
                                      size: 28,
                                    ),
                                    tooltip: 'Sign Out',
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Game Title & Subtitle
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _showAdminLoginDialog(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'LUDO REALM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: theme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Obx(() {
                            if (!authCtrl.isSignedIn) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              'Signed in as ${authCtrl.displayName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textSecondary,
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                          Text(
                            'Online Multiplayer, Offline & Vs Computer',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // RESUME SAVED GAME BUTTON
                    GetBuilder<LudoController>(
                      builder: (lController) {
                        if (!lController.hasSavedGameAvailable) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: ElevatedButton(
                            onPressed: () {
                              PermissionService.showMandatoryPermissionDialog(
                                context,
                                () async {
                                  final loaded =
                                      await lController.loadSavedGame();
                                  if (loaded) {
                                    Get.to(() => const GameScreen());
                                  }
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Colors.greenAccent.shade700,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.greenAccent.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  'RESUME GAME',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // 1. Mode Selection Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.gridLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Game Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModeTile(
                                  title: 'Vs Computer',
                                  icon: Icons.smart_toy,
                                  mode: GameMode.vsComputer,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildModeTile(
                                  title: 'Pass & Play',
                                  icon: Icons.groups,
                                  mode: GameMode.passAndPlay,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildModeTile(
                                  title: 'Online Room',
                                  icon: Icons.public,
                                  mode: GameMode.onlineMultiplayer,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ONLINE MULTIPLAYER HUB vs OFFLINE SETUP
                    if (selectedMode == GameMode.onlineMultiplayer) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.blue, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wifi_tethering,
                                    color: theme.blue, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Online Multiplayer Hub',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Play with friends online! Create a private room or join using a 6-digit invite code.',
                              style: TextStyle(
                                  fontSize: 13, color: theme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _showCreateRoomDialog(context, theme),
                                    icon: const Icon(Icons.add_box_rounded),
                                    label: const Text('CREATE ROOM'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      backgroundColor: theme.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showJoinRoomDialog(context, theme),
                                    icon: const Icon(Icons.vpn_key_rounded),
                                    label: const Text('JOIN ROOM'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      foregroundColor: theme.blue,
                                      side: BorderSide(
                                          color: theme.blue, width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // 2. Player Count Selector Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.gridLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Number of Players',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [2, 3, 4].map((count) {
                                final isSelected = selectedPlayerCount == count;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          selectedPlayerCount = count;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        backgroundColor: isSelected
                                            ? theme.blue
                                            : theme.boardBg,
                                        foregroundColor: isSelected
                                            ? Colors.white
                                            : theme.textPrimary,
                                        elevation: isSelected ? 4 : 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isSelected
                                                ? theme.blue
                                                : theme.gridLine,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '$count Players',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Player Customization Inputs Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.gridLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Player Names',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(selectedPlayerCount, (index) {
                              final colors = [
                                Colors.redAccent,
                                Colors.green,
                                Colors.amber.shade700,
                                Colors.blue,
                              ];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: TextField(
                                  controller: nameControllers[index],
                                  style: TextStyle(color: theme.textPrimary),
                                  decoration: InputDecoration(
                                    labelText:
                                        selectedMode == GameMode.vsComputer &&
                                                index > 0
                                            ? 'Bot $index'
                                            : 'Player ${index + 1} Name',
                                    labelStyle:
                                        TextStyle(color: theme.textSecondary),
                                    prefixIcon: Icon(
                                      selectedMode == GameMode.vsComputer &&
                                              index > 0
                                          ? Icons.smart_toy
                                          : Icons.person,
                                      color: colors[index % colors.length],
                                    ),
                                    filled: true,
                                    fillColor: theme.boardBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: theme.gridLine),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: theme.gridLine),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // START NEW GAME Button
                      ElevatedButton(
                        onPressed: () {
                          PermissionService.showMandatoryPermissionDialog(
                            context,
                            () {
                              final names = nameControllers
                                  .take(selectedPlayerCount)
                                  .map((c) => c.text.trim())
                                  .toList();

                              ludoCtrl.startNewGame(
                                mode: selectedMode,
                                count: selectedPlayerCount,
                                customNames: names,
                              );

                              Get.to(() => const GameScreen());
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: Colors.amber.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 32),
                            SizedBox(width: 8),
                            Text(
                              'START NEW GAME',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeTile({
    required String title,
    required IconData icon,
    required GameMode mode,
    required dynamic theme,
  }) {
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          selectedMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.blue.withOpacity(0.2) : theme.boardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.blue : theme.gridLine,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? theme.blue : theme.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.textPrimary : theme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, dynamic theme) {
    int roomMaxPlayers = 4;
    final nameCtrl = TextEditingController(
      text: Get.find<AuthController>().displayName.isNotEmpty
          ? Get.find<AuthController>().displayName
          : 'Player Host',
    );

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: theme.cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Create Online Room',
              style: TextStyle(
                  color: theme.textPrimary, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Display Name',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.person, color: Colors.blueAccent),
                    filled: true,
                    fillColor: theme.boardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Maximum Players Capacity (Min 2 to start)',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [2, 3, 4].map((count) {
                    final isSel = roomMaxPlayers == count;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: () =>
                              setDlgState(() => roomMaxPlayers = count),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSel ? theme.blue : theme.boardBg,
                            foregroundColor:
                                isSel ? Colors.white : theme.textPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('$count'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final uid =
                      Get.find<AuthController>().currentUser.value?.uid ??
                          'uid_${DateTime.now().millisecondsSinceEpoch}';

                  Get.back();
                  Get.dialog(
                    const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    barrierDismissible: false,
                  );

                  try {
                    final photoUrl = Get.find<AuthController>().photoUrl;
                    final code = await OnlineMultiplayerService.createRoom(
                      maxPlayers: roomMaxPlayers,
                      hostName: name,
                      hostUid: uid,
                      hostPhotoUrl: photoUrl,
                    );
                    Get.back();
                    Get.to(
                        () => RoomLobbyScreen(roomCode: code, currentUid: uid));
                  } catch (e) {
                    Get.back();
                    AppAlert.showError(
                      e.toString(),
                      title: 'Creation Failed',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: theme.blue),
                child: const Text('Create & Open Lobby'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context, dynamic theme) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController(
      text: Get.find<AuthController>().displayName.isNotEmpty
          ? Get.find<AuthController>().displayName
          : 'Player',
    );

    Get.dialog(
      AlertDialog(
        backgroundColor: theme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Join Online Room',
          style:
              TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '6-Digit Invite Code',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '581920',
                filled: true,
                fillColor: theme.boardBg,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Display Name',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Colors.blueAccent),
                filled: true,
                fillColor: theme.boardBg,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              final name = nameCtrl.text.trim();
              final uid = Get.find<AuthController>().currentUser.value?.uid ??
                  'uid_${DateTime.now().millisecondsSinceEpoch}';

              if (code.length != 6) {
                AppAlert.showWarning(
                  'Please enter a valid 6-digit room code.',
                  title: 'Invalid Code',
                );
                return;
              }

              Get.back();
              Get.dialog(
                const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                barrierDismissible: false,
              );

              try {
                final photoUrl = Get.find<AuthController>().photoUrl;
                await OnlineMultiplayerService.joinRoom(
                  roomCode: code,
                  playerName: name,
                  playerUid: uid,
                  photoUrl: photoUrl,
                );
                Get.back();
                Get.to(() => RoomLobbyScreen(roomCode: code, currentUid: uid));
              } catch (e) {
                Get.back();
                AppAlert.showError(
                  e.toString(),
                  title: 'Join Failed',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.blue),
            child: const Text('Join Room'),
          ),
        ],
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final authCtrl = Get.find<AuthController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Admin Portal Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Admin Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await authCtrl.signInAdmin(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                );
                Get.back();
                Get.to(() => const AdminPanelScreen());
              } catch (e) {
                AppAlert.showError(
                  e.toString(),
                  title: 'Login Failed',
                );
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('📜 Ludo Rules'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '1. Rolling a 6 earns a bonus roll and opens a token from base.'),
              SizedBox(height: 6),
              Text('2. Rolling three 6s in a row forfeits your turn.'),
              SizedBox(height: 6),
              Text(
                  '3. Landing on an opponent token captures it back to base and grants a bonus turn.'),
              SizedBox(height: 6),
              Text(
                  '4. Safe tiles with star icons protect tokens from capture.'),
              SizedBox(height: 6),
              Text('5. First player to reach home with all 4 tokens wins!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
