import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/screens/command_diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.example.game_tracker/command_platform');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'executeCommand') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          final type = args['type'] as String;

          return {
            'status': 'SUCCESS',
            'commandId': 'cmd_diag_123',
            'traceId': 'trace_diag_123',
            'featureId': 'FEATURE_$type',
            'durationMs': 12,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('CommandDiagnosticsScreen renders and dispatches test commands', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommandDiagnosticsScreen(),
      ),
    );

    expect(find.text('Engine Diagnostics & Telemetry'), findsOneWidget);
    expect(find.text('Ping'), findsOneWidget);
    expect(find.text('Shot'), findsOneWidget);
    expect(find.text('Cam'), findsOneWidget);
    expect(find.text('Loc'), findsOneWidget);

    await tester.tap(find.text('Ping'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PING - SUCCESS'), findsOneWidget);
    expect(find.textContaining('cmd_diag_123'), findsOneWidget);
  });
}
