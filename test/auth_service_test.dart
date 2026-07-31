import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/auth_service.dart';

void main() {
  group('AuthUser Data Model & Admin Credentials Tests', () {
    test('AuthUser correctly serializes to JSON', () {
      final user = AuthUser(
        uid: 'user-uid-101',
        email: 'player1@ludorealm.com',
        displayName: 'Player One',
        photoUrl: 'https://example.com/avatar.png',
        isAdmin: false,
      );

      final json = user.toJson();
      expect(json['uid'], 'user-uid-101');
      expect(json['email'], 'player1@ludorealm.com');
      expect(json['displayName'], 'Player One');
      expect(json['photoUrl'], 'https://example.com/avatar.png');
      expect(json['isAdmin'], false);
    });

    test('AuthUser correctly deserializes from JSON', () {
      final json = {
        'uid': 'user-uid-202',
        'email': 'admin@yopmail.com',
        'displayName': 'Admin Commander',
        'photoUrl': null,
        'isAdmin': true,
      };

      final user = AuthUser.fromJson(json);
      expect(user.uid, 'user-uid-202');
      expect(user.email, 'admin@yopmail.com');
      expect(user.displayName, 'Admin Commander');
      expect(user.photoUrl, isNull);
      expect(user.isAdmin, isTrue);
    });

    test('Admin email constant detection logic', () {
      const email1 = 'admin@yopmail.com';
      const email2 = 'ADMIN@YOPMAIL.COM';
      const email3 = 'player@yopmail.com';

      expect(email1.toLowerCase() == AuthService.adminEmail, isTrue);
      expect(email2.toLowerCase() == AuthService.adminEmail, isTrue);
      expect(email3.toLowerCase() == AuthService.adminEmail, isFalse);
    });

    test('Default AuthUser values when photoUrl is omitted', () {
      final user = AuthUser(
        uid: 'uid-999',
        email: 'test@example.com',
        displayName: 'Test User',
        isAdmin: false,
      );

      expect(user.photoUrl, isNull);
      expect(user.isAdmin, isFalse);
    });
  });
}
