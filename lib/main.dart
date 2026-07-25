import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controllers/theme_controller.dart';
import 'controllers/ludo_controller.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for smartphone & tablet screens
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Register GetX Controllers
  Get.put(ThemeController());
  Get.put(LudoController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();

    return GetBuilder<ThemeController>(
      builder: (ctrl) {
        return GetMaterialApp(
          title: 'Ludo Kingdom',
          debugShowCheckedModeBanner: false,
          theme: ctrl.themeData,
          home: const HomeScreen(),
        );
      },
    );
  }
}
