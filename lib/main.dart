import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_tracker/firebase_options.dart';
import 'package:get/get.dart';
import 'controllers/theme_controller.dart';
import 'controllers/ludo_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/admin_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_screenshot_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }

  // Set preferred orientations for smartphone & tablet screens
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (ctrl) {
        return RepaintBoundary(
          key: AppScreenshotService.screenshotKey,
          child: GetMaterialApp(
            title: 'Ludo Kingdom',
            debugShowCheckedModeBanner: false,
            theme: ctrl.themeData,
            home: Obx(() {
              final authCtrl = Get.find<AuthController>();
              return authCtrl.isSignedIn
                  ? const HomeScreen()
                  : const AuthScreen();
            }),
          ),
        );
      },
    );
  }
}
