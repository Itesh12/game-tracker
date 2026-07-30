import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_service.dart';

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
    firestore.settings = const Settings(persistenceEnabled: true);
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

  static AuthUser _userFromFirebase(User firebaseUser, {bool isAdmin = false}) {
    return AuthUser.fromFirebaseUser(
      firebaseUser,
      isAdmin: isAdmin,
    );
  }

  static Future<AuthUser?> loadCurrentUser() async {
    final firebaseUser = auth.currentUser;
    if (firebaseUser != null) {
      final isAdmin = firebaseUser.email?.toLowerCase() == adminEmail;
      final doc = await firestore.collection(usersCollection).doc(firebaseUser.uid).get();
      final photoUrl = doc.data()?['photoUrl'] as String?;
      final displayName = doc.data()?['displayName'] as String?;

      final authUser = AuthUser.fromFirebaseUser(
        firebaseUser,
        isAdmin: isAdmin,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      await syncUser(authUser);
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
    await _ensureUserDocument(user);
    await cacheUser(user);

    // Sync to device record
    final deviceId = await AdminService.getOrCreateDeviceId();
    await firestore.collection('devices').doc(deviceId).set({
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
    }, SetOptions(merge: true));

    return user;
  }

  static Future<AuthUser> signInPlayer({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      final doc = await firestore.collection(usersCollection).doc(credential.user!.uid).get();
      final photoUrl = doc.data()?['photoUrl'] as String?;
      final displayName = doc.data()?['displayName'] as String?;

      final user = AuthUser.fromFirebaseUser(
        credential.user!,
        isAdmin: email.toLowerCase() == adminEmail,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      await _ensureUserDocument(user);
      await cacheUser(user);

      // Sync to device record
      final deviceId = await AdminService.getOrCreateDeviceId();
      await firestore.collection('devices').doc(deviceId).set({
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
      }, SetOptions(merge: true));

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

    await firestore.collection(usersCollection).doc(uid).set(updates, SetOptions(merge: true));

    final deviceId = await AdminService.getOrCreateDeviceId();
    final deviceUpdates = <String, dynamic>{};
    if (displayName != null) deviceUpdates['displayName'] = displayName;
    if (photoUrl != null) deviceUpdates['photoUrl'] = photoUrl;
    if (deviceUpdates.isNotEmpty) {
      await firestore.collection('devices').doc(deviceId).set(deviceUpdates, SetOptions(merge: true));
    }

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
      await _ensureUserDocument(user);
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
        await _ensureUserDocument(user);
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
    await auth.signOut();
    await clearCachedUser();
  }

  static Future<void> _ensureUserDocument(AuthUser user) async {
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
  }

  static Future<void> syncUser(AuthUser user) async {
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
  }

  static Future<bool> _cachedEmailMatches(String email) async {
    final cached = await loadCachedUser();
    return cached != null && cached.email.toLowerCase() == email.toLowerCase();
  }
}
