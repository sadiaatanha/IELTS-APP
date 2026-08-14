import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePass = true;
  bool obscureConfirm = true;
  bool isLoading = false;

  String? nameError;
  String? emailError;
  String? passwordError;
  String? confirmError;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);
  static const snackBarColor = Color(0xFFE5E7EB);

  bool isEmailValid(String email) {
    return RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void showMessage(String message) {
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

  Future<void> submit() async {
    setState(() {
      nameError = null;
      emailError = null;
      passwordError = null;
      confirmError = null;
    });

    bool ok = true;

    if (nameController.text.trim().length < 2) {
      nameError = "Minimum 2 characters required";
      ok = false;
    }

    if (!isEmailValid(emailController.text.trim())) {
      emailError = "Invalid email";
      ok = false;
    }

    if (passwordController.text.length < 6) {
      passwordError = "Minimum 6 characters required";
      ok = false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      confirmError = "Passwords do not match";
      ok = false;
    }

    if (!ok) {
      setState(() {});
      return;
    }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        emailRedirectTo: 'http://localhost:3000',
        data: {
          'full_name': nameController.text.trim(),
          'email': emailController.text.trim().toLowerCase(),
          'phone': '',
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        showMessage(
          "Confirmation email sent. Please verify your email, then login.",
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage("Registration Failed: $e");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 14,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: const TextStyle(color: subTextColor),
        prefixIcon: Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget outlineButton({
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
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;

            final double cardWidth = (screenWidth * 0.35).clamp(300.0, 500.0);

            final bool isSmallScreen = screenWidth <= 320;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 18,
                  vertical: 18,
                ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                          decoration: BoxDecoration(
                            color: lightPrimary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "SUCCESS STARTS HERE",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Complete your registration to begin your IELTS journey.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 22 : 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Improve your English skills with practice and tests",
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        inputField(
                          label: "Name",
                          icon: Icons.person_outline,
                          controller: nameController,
                          errorText: nameError,
                        ),
                        const SizedBox(height: 14),
                        inputField(
                          label: "Email",
                          icon: Icons.email_outlined,
                          controller: emailController,
                          errorText: emailError,
                        ),
                        const SizedBox(height: 14),
                        inputField(
                          label: "Password",
                          icon: Icons.lock_outline,
                          controller: passwordController,
                          errorText: passwordError,
                          obscureText: obscurePass,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: subTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePass = !obscurePass;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        inputField(
                          label: "Confirm Password",
                          icon: Icons.lock_outline,
                          controller: confirmPasswordController,
                          errorText: confirmError,
                          obscureText: obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: subTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        outlineButton(
                          text: "Sign Up",
                          icon: Icons.person_add_alt_1_outlined,
                          onPressed: submit,
                          loading: isLoading,
                        ),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            "Already have an account?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        outlineButton(
                          text: "Login Page",
                          icon: Icons.login_outlined,
                          onPressed: goToLogin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
