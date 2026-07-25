import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController resetEmailController = TextEditingController();

  bool isSignup = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    resetEmailController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext context, dynamic theme, AuthController authCtrl) {
    resetEmailController.text = emailController.text.trim();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardBg,
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: theme.blue),
            const SizedBox(width: 10),
            Text(
              'Reset Password',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your registered email address to receive a password reset link.',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: theme.textSecondary),
                prefixIcon: Icon(Icons.email_outlined, color: theme.blue),
                filled: true,
                fillColor: theme.boardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.gridLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.gridLine),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                Get.snackbar(
                  'Input Required',
                  'Please enter your email address.',
                  backgroundColor: Colors.orangeAccent,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              try {
                Get.back();
                await authCtrl.resetPassword(email);
                Get.snackbar(
                  'Reset Email Sent',
                  'A password reset link has been sent to $email.',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 4),
                );
              } catch (error) {
                Get.snackbar(
                  'Reset Failed',
                  error.toString(),
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final theme = Get.find<ThemeController>().currentTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Hero Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.blue.withOpacity(0.18),
                      boxShadow: [
                        BoxShadow(
                          color: theme.blue.withOpacity(0.35),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outlined,
                      size: 52,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    isSignup ? 'Create Account' : 'Welcome Back',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSignup
                        ? 'Sign up to play Ludo Kingdom and sync progress'
                        : 'Sign in to access your Ludo Kingdom profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Main Form Card Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.gridLine, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Display Name Field (Sign Up Mode)
                        if (isSignup) ...[
                          TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Display Name',
                              labelStyle: TextStyle(color: theme.textSecondary),
                              prefixIcon: Icon(Icons.person_outline, color: theme.blue),
                              filled: true,
                              fillColor: theme.boardBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: theme.gridLine),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: theme.gridLine),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: TextStyle(color: theme.textSecondary),
                            prefixIcon: Icon(Icons.email_outlined, color: theme.blue),
                            filled: true,
                            fillColor: theme.boardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.gridLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.gridLine),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: theme.textSecondary),
                            prefixIcon: Icon(Icons.lock_outline, color: theme.blue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: theme.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: theme.boardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.gridLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.gridLine),
                            ),
                          ),
                        ),

                        // Forgot Password Button (Sign In Mode)
                        if (!isSignup) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showForgotPasswordDialog(context, theme, authCtrl),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.blue,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit Button
                        Obx(() {
                          if (authCtrl.isLoading.value) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return ElevatedButton(
                            onPressed: () async {
                              final email = emailController.text.trim();
                              final password = passwordController.text.trim();
                              final name = nameController.text.trim();

                              if (email.isEmpty || password.isEmpty) {
                                Get.snackbar(
                                  'Input Required',
                                  'Please fill in all required fields.',
                                  backgroundColor: Colors.orangeAccent,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }

                              try {
                                if (isSignup) {
                                  if (name.isEmpty) {
                                    throw 'Please enter a display name.';
                                  }
                                  await authCtrl.signUpPlayer(
                                    email: email,
                                    password: password,
                                    displayName: name,
                                  );
                                } else {
                                  await authCtrl.signInPlayer(
                                    email: email,
                                    password: password,
                                  );
                                }
                              } catch (error) {
                                Get.snackbar(
                                  'Authentication Failed',
                                  error.toString(),
                                  backgroundColor: Colors.redAccent,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isSignup ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Toggle Sign In / Create Account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isSignup
                                  ? 'Already have an account?'
                                  : "Don't have an account?",
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isSignup = !isSignup;
                                });
                              },
                              child: Text(
                                isSignup ? 'Sign In' : 'Create One',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Admin Credentials Hint Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardBg.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.gridLine.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: theme.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Admin Login: admin@yopmail.com | Test@123',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
