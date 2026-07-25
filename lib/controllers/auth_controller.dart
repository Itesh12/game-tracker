import 'package:get/get.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final Rxn<AuthUser> currentUser = Rxn<AuthUser>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isSignedIn => currentUser.value != null;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;
  String get displayName => currentUser.value?.displayName ?? '';
  String get email => currentUser.value?.email ?? '';

  Future<void> initialize() async {
    await AuthService.initialize();
    final user = await AuthService.loadCurrentUser();
    if (user != null) {
      currentUser.value = user;
    }
  }

  Future<void> signUpPlayer({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await AuthService.signUpPlayer(
        email: email,
        password: password,
        displayName: displayName,
      );
      currentUser.value = user;
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
      final user = await AuthService.signInPlayer(email: email, password: password);
      currentUser.value = user;
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
      final user = await AuthService.signInAdmin(email: email, password: password);
      currentUser.value = user;
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
