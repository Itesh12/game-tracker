import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:game_tracker/main.dart';
import 'package:game_tracker/controllers/theme_controller.dart';
import 'package:game_tracker/controllers/ludo_controller.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put(ThemeController());
    Get.put(LudoController());
  });

  testWidgets('Ludo kingdom home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('LUDO KINGDOM'), findsOneWidget);
    expect(find.text('START NEW GAME'), findsOneWidget);
  });
}
