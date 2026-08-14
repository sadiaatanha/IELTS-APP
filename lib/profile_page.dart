import 'dart:io';
import 'dart:typed_data';

import 'login_page.dart';

import 'home_page.dart';
import 'analytics_page.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  final bool showBottomNav;

  const ProfilePage({
    super.key,
    this.showBottomNav = true,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? avatarUrl;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);
  static const snackBarColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showMessage("User not logged in");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? '',
          'phone': user.userMetadata?['phone'] ?? '',
          'avatar_url': null,
        });

        nameController.text = user.userMetadata?['full_name'] ?? '';
        phoneController.text = user.userMetadata?['phone'] ?? '';
        emailController.text = user.email ?? '';
        avatarUrl = null;
      } else {
        nameController.text =
            data['full_name'] ?? user.userMetadata?['full_name'] ?? '';
        phoneController.text =
            data['phone'] ?? user.userMetadata?['phone'] ?? '';
        emailController.text = data['email'] ?? user.email ?? '';
        avatarUrl = data['avatar_url'];
      }
    } catch (e) {
      _showMessage("Profile load failed: $e");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'avatar_url': avatarUrl,
      });

      _showMessage("Profile updated successfully");
    } catch (e) {
      _showMessage("Update failed: $e");
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (image == null) return;

      final fileExt = image.path.split('.').last;
      final filePath = '${user.id}/profile.$fileExt';

      if (kIsWeb) {
        final Uint8List bytes = await image.readAsBytes();

        await supabase.storage.from('profile-pictures').uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        final file = File(image.path);

        await supabase.storage.from('profile-pictures').upload(
              filePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      }

      final publicUrl =
          supabase.storage.from('profile-pictures').getPublicUrl(filePath);

      setState(() {
        avatarUrl = publicUrl;
      });

      await _saveProfile();
      _showMessage("Profile picture updated");
    } catch (e) {
      _showMessage("Image upload failed: $e");
    }
  }

  Future<void> _deleteProfilePicture() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('profiles').update({
        'avatar_url': null,
      }).eq('id', user.id);

      setState(() {
        avatarUrl = null;
      });

      _showMessage("Profile picture deleted");
    } catch (e) {
      _showMessage("Delete failed: $e");
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: snackBarColor,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: const TextStyle(
          fontSize: 14,
          color: textColor,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: subTextColor,
          ),
          prefixIcon: Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineActionButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox.shrink()
            : Icon(
                icon,
                size: 20,
                color: primaryColor,
              ),
        label: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(
            color: primaryColor,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(
          color: textColor,
        ),
        title: const Text(
          "Profile",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final double cardWidth =
                    (screenWidth * 0.35).clamp(300.0, 500.0);
                final bool isSmallScreen = screenWidth <= 320;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 18,
                    vertical: 18,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: cardWidth,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: lightPrimary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                "Keep your IELTSpire profile updated to track your IELTS practice progress, saved scores, and personal learning history accurately.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: isSmallScreen ? 52 : 58,
                                  backgroundColor: lightPrimary,
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage(avatarUrl!)
                                      : null,
                                  child: avatarUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: isSmallScreen ? 58 : 65,
                                          color: primaryColor,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: InkWell(
                                    onTap: _pickAndUploadImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: _pickAndUploadImage,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  label: const Text(
                                    "Update",
                                    style: TextStyle(color: primaryColor),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 22,
                                  color: Colors.grey.shade300,
                                ),
                                TextButton.icon(
                                  onPressed: avatarUrl == null
                                      ? null
                                      : _deleteProfilePicture,
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: avatarUrl == null
                                        ? Colors.grey
                                        : primaryColor,
                                  ),
                                  label: Text(
                                    "Delete",
                                    style: TextStyle(
                                      color: avatarUrl == null
                                          ? Colors.grey
                                          : primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _inputField(
                              label: "Full Name",
                              icon: Icons.person_outline,
                              controller: nameController,
                            ),
                            _inputField(
                              label: "Email",
                              icon: Icons.email_outlined,
                              controller: emailController,
                              readOnly: true,
                            ),
                            _inputField(
                              label: "Phone",
                              icon: Icons.phone_outlined,
                              controller: phoneController,
                            ),
                            const SizedBox(height: 8),
                            _outlineActionButton(
                              text: "Save Profile",
                              icon: Icons.save_outlined,
                              onPressed: _saveProfile,
                              loading: isSaving,
                            ),
                            const SizedBox(height: 12),
                            _outlineActionButton(
                              text: "Logout",
                              icon: Icons.logout,
                              onPressed: _logout,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

      bottomNavigationBar:
       widget.showBottomNav
        ? BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Analytics",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      )
       : null,
    );
  }
}