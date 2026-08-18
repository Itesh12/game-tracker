import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_tracker/firebase_options.dart';
import 'package:get/get.dart';
import 'controllers/theme_controller.dart';
import 'controllers/ludo_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/admin_controller.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_screenshot_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError caught: ${details.exception}');
    };

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
    }

    // Set preferred orientations for smartphone & tablet screens
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}

    // Register GetX Controllers
    Get.put(ThemeController());
    Get.put(LudoController());
    Get.put(AuthController());
    Get.put(AdminController());

    try {
      await Get.find<AuthController>().initialize();
    } catch (error) {
      debugPrint('Auth initialization failed: $error');
    }

    try {
      await Get.find<AdminController>().initialize();
    } catch (error) {
      debugPrint('Admin initialization failed: $error');
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppScreenshotService.captureAndCacheCurrentFrame());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(AppScreenshotService.captureAndCacheCurrentFrame());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (ctrl) {
        return RepaintBoundary(
          key: AppScreenshotService.screenshotKey,
          child: GetMaterialApp(
            title: 'Ludo Realm',
            debugShowCheckedModeBanner: false,
            theme: ctrl.themeData,
            home: Obx(() {
              final authCtrl = Get.find<AuthController>();
              if (!authCtrl.isSignedIn) {
                return const AuthScreen();
              }
              return authCtrl.isAdmin
                  ? const AdminPanelScreen()
                  : const HomeScreen();
            }),
          ),
        );
      },
    );
  }
}
