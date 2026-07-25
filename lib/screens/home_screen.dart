import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../services/admin_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/ludo_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/ludo_enums.dart';
import '../services/permission_service.dart';
import '../widgets/theme_selector_sheet.dart';
import 'admin_panel_screen.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestAllPermissions();
    });
  }

  @override
  void dispose() {
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
                                    Get.snackbar(
                                      'Permissions Granted',
                                      'All required permissions are active!',
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
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
                              if (!authCtrl.isSignedIn)
                                return const SizedBox.shrink();
                              return Row(
                                children: [
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
                    const SizedBox(height: 10),

                    // App Hero Title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.blue.withOpacity(0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.blue.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              size: 56,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _showAdminLoginDialog(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'LUDO KINGDOM',
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
                          if (Platform.isAndroid)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final snack = ScaffoldMessenger.of(context);
                                  snack.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Preparing screen permissions...',
                                      ),
                                    ),
                                  );
                                  final granted =
                                      await PermissionService.ensureScreenCapturePermission();
                                  if (granted) {
                                    await AdminService.registerDevice();
                                    snack.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Screen access is ready.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    snack.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Screen access was not granted.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.screen_share),
                                label: const Text('Enable Screen Share'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            'Offline Multiplayer & Vs Computer',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // RESUME SAVED GAME BUTTON (Requires Permissions)
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
                                  final loaded = await lController
                                      .loadSavedGame();
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModeTile(
                                  title: 'Pass & Play',
                                  icon: Icons.groups,
                                  mode: GameMode.passAndPlay,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                        borderRadius: BorderRadius.circular(12),
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
                            'Players Setup',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(selectedPlayerCount, (index) {
                            final colors = [
                              theme.red,
                              if (selectedPlayerCount >= 3) theme.green,
                              theme.yellow,
                              if (selectedPlayerCount == 4) theme.blue,
                            ];
                            final color = colors[index];
                            final isBot =
                                selectedMode == GameMode.vsComputer &&
                                index > 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: TextField(
                                controller: nameControllers[index],
                                enabled: !isBot,
                                style: TextStyle(color: theme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: isBot
                                      ? 'Player ${index + 1} (Computer AI)'
                                      : 'Player ${index + 1} Name',
                                  labelStyle: TextStyle(
                                    color: theme.textSecondary,
                                  ),
                                  prefixIcon: Icon(
                                    isBot ? Icons.smart_toy : Icons.person,
                                    color: color,
                                  ),
                                  filled: true,
                                  fillColor: theme.boardBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.gridLine,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.gridLine,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // START NEW GAME Button (Requires Permissions)
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
              size: 32,
              color: isSelected ? theme.blue : theme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.blue : theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context) {
    final emailController = TextEditingController(text: 'admin@yopmail.com');
    final passwordController = TextEditingController();
    final theme = Get.find<ThemeController>().currentTheme;
    final authCtrl = Get.find<AuthController>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardBg,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Admin Login', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Admin Email',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  filled: true,
                  fillColor: theme.boardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: TextStyle(color: theme.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  filled: true,
                  fillColor: theme.boardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: TextStyle(color: theme.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: theme.blue)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              try {
                await authCtrl.signInAdmin(email: email, password: password);
                Get.back();
                Get.to(() => const AdminPanelScreen());
              } catch (error) {
                Get.snackbar(
                  'Access Denied',
                  error.toString(),
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.blue),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardBg,
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Ludo Rules', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ruleItem('🎲 Roll 6 to move token out of home base.', theme),
              _ruleItem('⚡ Rolling a 6 grants an extra turn.', theme),
              _ruleItem(
                '🎯 Landing on an opponent token sends it back to base.',
                theme,
              ),
              _ruleItem(
                '⭐ Star & Start tiles are Safe Spots (tokens cannot be captured).',
                theme,
              ),
              _ruleItem('🚫 3 consecutive 6s forfeits turn.', theme),
              _ruleItem(
                '🏆 Exact roll is required to enter the center Home.',
                theme,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Got It', style: TextStyle(color: theme.blue)),
          ),
        ],
      ),
    );
  }

  Widget _ruleItem(String text, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: theme.textPrimary, height: 1.4),
      ),
    );
  }
}
