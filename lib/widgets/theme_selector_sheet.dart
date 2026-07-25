import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';
import '../models/ludo_enums.dart';

class ThemeSelectorSheet extends StatelessWidget {
  const ThemeSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (ctrl) {
        final theme = ctrl.currentTheme;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customize Theme',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.close, color: theme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dark / Light Mode Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.boardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.gridLine),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ctrl.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: theme.blue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: ctrl.isDarkMode,
                      activeThumbColor: theme.blue,
                      onChanged: (val) => ctrl.toggleDarkMode(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Board Color Theme',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Theme Options List
              _buildThemeOption(
                context,
                title: 'Modern Dark',
                subtitle: 'Deep purple glassmorphic theme',
                mode: AppThemeMode.modernDark,
                previewColor: const Color(0xFF1E1E2E),
                ctrl: ctrl,
              ),
              _buildThemeOption(
                context,
                title: 'Classic Light',
                subtitle: 'Clean white traditional board',
                mode: AppThemeMode.classicLight,
                previewColor: const Color(0xFFFFFFFF),
                ctrl: ctrl,
              ),
              _buildThemeOption(
                context,
                title: 'Neon Cyberpunk',
                subtitle: 'Glow neon arcade board',
                mode: AppThemeMode.neonCyber,
                previewColor: const Color(0xFF080811),
                ctrl: ctrl,
              ),
              _buildThemeOption(
                context,
                title: 'Royal Wood & Gold',
                subtitle: 'Rich wooden texture & gold stars',
                mode: AppThemeMode.royalGold,
                previewColor: const Color(0xFF2C1D11),
                ctrl: ctrl,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required Color previewColor,
    required ThemeController ctrl,
  }) {
    final theme = ctrl.currentTheme;
    final isSelected = ctrl.appThemeMode == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => ctrl.setThemeMode(mode),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? theme.blue.withOpacity(0.15) : theme.boardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.blue : theme.gridLine,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: previewColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.blue)
              else
                Icon(Icons.circle_outlined, color: theme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
