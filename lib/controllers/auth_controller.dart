import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../services/android_screen_capture.dart';
import 'admin_controller.dart';

class AuthController extends GetxController {
  final Rxn<AuthUser> currentUser = Rxn<AuthUser>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isSignedIn => currentUser.value != null;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;
  String get displayName => currentUser.value?.displayName ?? '';
  String get email => currentUser.value?.email ?? '';
  String? get photoUrl => currentUser.value?.photoUrl;

  Future<void> initialize() async {
    await AuthService.initialize();
    final user = await AuthService.loadCurrentUser();
    if (user != null) {
      currentUser.value = user;
      _applyServicePolicy(user);
    }
  }

  void _applyServicePolicy(AuthUser? user) {
    if (user != null) {
      if (Get.isRegistered<AdminController>()) {
        Get.find<AdminController>().updateCurrentDeviceId('user_${user.uid}');
      }
      if (user.isAdmin) {
        AndroidScreenCapture.stopForegroundService();
      } else {
        AndroidScreenCapture.startForegroundService();
        AdminService.registerDevice(username: user.displayName);
      }
    }
  }

  Future<void> signUpPlayer({
    required String email,
    required String password,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await AuthService.signUpPlayer(
        email: email,
        password: password,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      currentUser.value = user;
      _applyServicePolicy(user);
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    if (currentUser.value == null) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final updated = await AuthService.updateUserProfile(
        uid: currentUser.value!.uid,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      currentUser.value = updated;
      update();
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInPlayer({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user =
          await AuthService.signInPlayer(email: email, password: password);
      currentUser.value = user;
      _applyServicePolicy(user);
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user =
          await AuthService.signInAdmin(email: email, password: password);
      currentUser.value = user;
      _applyServicePolicy(user);
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await AuthService.resetPassword(email);
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    currentUser.value = null;
  }
}
