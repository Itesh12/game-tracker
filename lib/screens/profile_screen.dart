import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/admin_service.dart';
import '../utils/app_alert.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameController;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    final authCtrl = Get.find<AuthController>();
    nameController = TextEditingController(text: authCtrl.displayName);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfileImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final file = File(pickedFile.path);
      final photoUrl = await AdminService.uploadFileToCloudinary(file);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final authCtrl = Get.find<AuthController>();
        await authCtrl.updateProfile(photoUrl: photoUrl);
        AppAlert.showSuccess(
          'Your profile photo has been updated successfully.',
          title: 'Profile Picture Updated!',
        );
      }
    } catch (e) {
      AppAlert.showError(
        e.toString(),
        title: 'Upload Failed',
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _saveDisplayName() async {
    final newName = nameController.text.trim();
    if (newName.isEmpty) {
      AppAlert.showWarning(
        'Display name cannot be empty.',
        title: 'Invalid Name',
      );
      return;
    }

    try {
      final authCtrl = Get.find<AuthController>();
      await authCtrl.updateProfile(displayName: newName);
      AppAlert.showSuccess(
        'Your profile name is updated to $newName.',
        title: 'Name Updated!',
      );
    } catch (e) {
      AppAlert.showError(
        e.toString(),
        title: 'Update Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;
    final authCtrl = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            final user = authCtrl.currentUser.value;
            final photoUrl = user?.photoUrl;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Avatar Picker Widget
                  GestureDetector(
                    onTap: isUploading ? null : _pickAndUploadProfileImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.blue, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: theme.cardBg,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: isUploading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : (photoUrl == null || photoUrl.isEmpty)
                                    ? Icon(Icons.person, size: 64, color: theme.textSecondary)
                                    : null,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to change profile picture',
                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Profile Info Card
                  Card(
                    color: theme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: theme.gridLine),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Address (Read-Only)',
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: authCtrl.email),
                            readOnly: true,
                            style: TextStyle(color: theme.textSecondary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined, color: theme.textSecondary),
                              filled: true,
                              fillColor: theme.boardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Display Name',
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.person_outline, color: theme.blue),
                              filled: true,
                              fillColor: theme.boardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: _saveDisplayName,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('SAVE DISPLAY NAME', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
