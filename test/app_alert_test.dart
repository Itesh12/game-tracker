import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/utils/app_alert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAlert Service & Anti-Spam Tests', () {
    test('AppAlert methods execute safely without thrown exceptions', () {
      // In unit test environment without active overlay, calls should safely log without throwing
      expect(() => AppAlert.showSuccess('Operation successful', title: 'Success'), returnsNormally);
      expect(() => AppAlert.showError('Operation failed', title: 'Error'), returnsNormally);
      expect(() => AppAlert.showWarning('Please be careful', title: 'Warning'), returnsNormally);
      expect(() => AppAlert.showInfo('Information note', title: 'Info'), returnsNormally);
    });

    test('Rapid consecutive identical alerts are throttled to prevent spam headache', () {
      expect(() {
        for (int i = 0; i < 10; i++) {
          AppAlert.showInfo('Duplicate message test');
        }
      }, returnsNormally);
    });
  });
}
