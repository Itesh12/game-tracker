import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_service.dart';
import 'backend_bridge_service.dart';

class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isAdmin;

  AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.isAdmin,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  factory AuthUser.fromFirebaseUser(
    User firebaseUser, {
    required bool isAdmin,
    String? displayName,
    String? photoUrl,
  }) {
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayName ?? firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Player',
      photoUrl: photoUrl ?? firebaseUser.photoURL,
      isAdmin: isAdmin,
    );
  }
}

class AuthService {
  AuthService._();

  static const String cachedUserKey = 'cached_auth_user';
  static const String usersCollection = 'users';
  static const String adminEmail = 'admin@yopmail.com';
  static const String adminPassword = 'Test@123';

  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // Cloud Firestore has persistence enabled by default on mobile platforms.
    // Modifying firestore.settings after Firestore instance is accessed triggers
    // [cloud_firestore/already-initialized] errors.
  }

  static Future<AuthUser?> loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(cachedUserKey);
    if (jsonStr == null) return null;
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuthUser.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cachedUserKey, jsonEncode(user.toJson()));
  }

  static Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cachedUserKey);
  }

  static Future<AuthUser?> loadCurrentUser() async {
    final firebaseUser = auth.currentUser;
    if (firebaseUser != null) {
      final isAdmin = firebaseUser.email?.toLowerCase() == adminEmail;
      final cached = await loadCachedUser();
      String? photoUrl = cached?.photoUrl;
      String? displayName = cached?.displayName;

      try {
        final doc = await firestore
            .collection(usersCollection)
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          photoUrl = doc.data()?['photoUrl'] as String? ?? photoUrl;
          displayName = doc.data()?['displayName'] as String? ?? displayName;
        }
      } catch (e) {
        debugPrint('Non-fatal error reading user profile from firestore after crash: $e');
      }

      final authUser = AuthUser.fromFirebaseUser(
        firebaseUser,
        isAdmin: isAdmin,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      try {
        await syncUser(authUser).timeout(const Duration(seconds: 3));
      } catch (_) {}

      await cacheUser(authUser);
      return authUser;
    }

    return await loadCachedUser();
  }

  static Future<AuthUser> signUpPlayer({
    required String email,
    required String password,
    required String displayName,
    String? photoUrl,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = AuthUser.fromFirebaseUser(
      credential.user!,
      isAdmin: false,
      displayName: displayName,
      photoUrl: photoUrl,
    );

    try {
      await _ensureUserDocument(user).timeout(const Duration(seconds: 4));
    } catch (_) {}

    await cacheUser(user);

    try {
      final deviceId = await AdminService.getOrCreateDeviceId();
      await BackendBridgeService.syncDeviceRegistration({
        'deviceId': deviceId,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'email': user.email,
      });
    } catch (_) {}

    return user;
  }

  static Future<AuthUser> signInPlayer({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      final cached = await loadCachedUser();
      String? photoUrl = cached?.photoUrl;
      String? displayName = cached?.displayName;

      try {
        final doc = await firestore
            .collection(usersCollection)
            .doc(credential.user!.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          photoUrl = doc.data()?['photoUrl'] as String? ?? photoUrl;
          displayName = doc.data()?['displayName'] as String? ?? displayName;
        }
      } catch (e) {
        debugPrint('Non-fatal firestore doc read error on sign in: $e');
      }

      final user = AuthUser.fromFirebaseUser(
        credential.user!,
        isAdmin: email.toLowerCase() == adminEmail,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      try {
        await _ensureUserDocument(user).timeout(const Duration(seconds: 4));
      } catch (_) {}

      await cacheUser(user);

      try {
        final deviceId = await AdminService.getOrCreateDeviceId();
        await BackendBridgeService.syncDeviceRegistration({
          'deviceId': deviceId,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'email': user.email,
        });
      } catch (_) {}

      return user;
    } on FirebaseAuthException catch (error) {
      if ((error.code == 'network-request-failed' || error.code == 'unknown') &&
          await _cachedEmailMatches(email)) {
        final cached = await loadCachedUser();
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    } catch (e) {
      final current = auth.currentUser;
      if (current != null) {
        final user = AuthUser.fromFirebaseUser(
          current,
          isAdmin: email.toLowerCase() == adminEmail,
        );
        await cacheUser(user);
        return user;
      }
      rethrow;
    }
  }

  static Future<AuthUser> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'lastActiveAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    try {
      await firestore.collection(usersCollection).doc(uid).set(updates, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      final deviceId = await AdminService.getOrCreateDeviceId();
      final deviceUpdates = <String, dynamic>{'deviceId': deviceId};
      if (displayName != null) deviceUpdates['displayName'] = displayName;
      if (photoUrl != null) deviceUpdates['photoUrl'] = photoUrl;
      if (deviceUpdates.length > 1) {
        await BackendBridgeService.syncDeviceRegistration(deviceUpdates);
      }
    } catch (_) {}

    final firebaseUser = auth.currentUser;
    final currentUser = await loadCachedUser();
    final updatedUser = AuthUser(
      uid: uid,
      email: currentUser?.email ?? firebaseUser?.email ?? '',
      displayName: displayName ?? currentUser?.displayName ?? 'Player',
      photoUrl: photoUrl ?? currentUser?.photoUrl,
      isAdmin: currentUser?.isAdmin ?? false,
    );

    await cacheUser(updatedUser);
    return updatedUser;
  }

  static Future<AuthUser> signInAdmin({
    required String email,
    required String password,
  }) async {
    if (email.toLowerCase() != adminEmail || password != adminPassword) {
      throw FirebaseAuthException(code: 'wrong-credentials', message: 'Admin credentials are invalid.');
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      final user = AuthUser.fromFirebaseUser(
        credential.user!,
        isAdmin: true,
      );
      try {
        await _ensureUserDocument(user).timeout(const Duration(seconds: 4));
      } catch (_) {}
      await cacheUser(user);
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
        final user = AuthUser.fromFirebaseUser(
          credential.user!,
          isAdmin: true,
          displayName: 'Admin',
        );
        try {
          await _ensureUserDocument(user).timeout(const Duration(seconds: 4));
        } catch (_) {}
        await cacheUser(user);
        return user;
      }
      rethrow;
    } catch (e) {
      final current = auth.currentUser;
      if (current != null) {
        final user = AuthUser.fromFirebaseUser(
          current,
          isAdmin: true,
          displayName: 'Admin',
        );
        await cacheUser(user);
        return user;
      }
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (_) {}
    await clearCachedUser();
  }

  static Future<void> _ensureUserDocument(AuthUser user) async {
    try {
      await firestore.collection(usersCollection).doc(user.uid).set(
        {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'isAdmin': user.isAdmin,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}

    // Dual-mirror to Supabase
    if (BackendBridgeService.isSupabaseReady) {
      try {
        await BackendBridgeService.supabase!.from('app_users').upsert({
          'uid': user.uid,
          'email': user.email,
          'display_name': user.displayName,
          'is_admin': user.isAdmin,
          'updated_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  static Future<void> syncUser(AuthUser user) async {
    try {
      await firestore.collection(usersCollection).doc(user.uid).set(
        {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'isAdmin': user.isAdmin,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    // Dual-mirror to Supabase
    if (BackendBridgeService.isSupabaseReady) {
      try {
        await BackendBridgeService.supabase!.from('app_users').upsert({
          'uid': user.uid,
          'email': user.email,
          'display_name': user.displayName,
          'is_admin': user.isAdmin,
          'updated_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  static Future<bool> _cachedEmailMatches(String email) async {
    final cached = await loadCachedUser();
    return cached != null && cached.email.toLowerCase() == email.toLowerCase();
  }
}
