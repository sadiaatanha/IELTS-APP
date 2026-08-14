import 'home_page.dart';
import 'register_page.dart';
import 'admin/admin_dashboard.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  String? _rememberedEmail;
  bool _autoUncheckedRememberMe = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  final RegExp _emailRegex = RegExp(
    r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChange);
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');

    if (!mounted) return;

    if (savedEmail != null && savedEmail.isNotEmpty) {
      _rememberedEmail = savedEmail.trim().toLowerCase();
      _emailController.text = savedEmail;

      setState(() {
        _rememberMe = true;
      });
    }
  }

  void _handleEmailChange() {
    if (!mounted) return;

    final currentEmail = _emailController.text.trim().toLowerCase();

    if (_rememberedEmail != null &&
        currentEmail.isNotEmpty &&
        currentEmail != _rememberedEmail &&
        _rememberMe) {
      setState(() {
        _rememberMe = false;
        _autoUncheckedRememberMe = true;
      });
    }
  }

  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setString('remembered_email', email);
      _rememberedEmail = email;
      _autoUncheckedRememberMe = false;
    } else {
      if (!_autoUncheckedRememberMe) {
        await prefs.remove('remembered_email');
        _rememberedEmail = null;
      }
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Enter email');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      _showSnackBar('Invalid email format');
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Enter password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileByEmail = await _supabase
          .from('profiles')
          .select('id, email, role, blocked')
          .ilike('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (profileByEmail == null) {
        _showSnackBar('Invalid email');
        return;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.user != null) {
        if (response.user!.emailConfirmedAt == null) {
          await _supabase.auth.signOut();
          _showSnackBar('Please verify your email before login');
          return;
        }

        final blocked = profileByEmail['blocked'] ?? false;

        if (blocked == true) {
          await _supabase.auth.signOut();
          _showSnackBar('Your account has been blocked by admin');
          return;
        }

        await _saveRememberedEmail(email);

        final role = (profileByEmail['role'] ?? 'user').toString();

        _showSnackBar('Login successful');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                role == 'admin' ? const AdminDashboardPage() : const HomePage(),
          ),
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      if (msg.contains('email not confirmed')) {
        _showSnackBar('Please verify your email before login');
      } else if (msg.contains('invalid login credentials')) {
        _showSnackBar('Invalid password');
      } else {
        _showSnackBar(e.message);
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('email') &&
          errorMessage.contains('column') &&
          errorMessage.contains('does not exist')) {
        _showSnackBar('profiles table e email column nai');
      } else {
        _showSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChange);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const redPrimary = Color(0xFFD62828);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 360 ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 58,
                        width: 58,
                        decoration: const BoxDecoration(
                          color: redPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'IELTSpire',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: redPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Practice smarter, achieve higher bands',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  _inputField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _inputField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: redPrimary,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                            _autoUncheckedRememberMe = false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redPrimary,
                        disabledBackgroundColor: redPrimary.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: redPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction:
          hint == 'Password' ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) {
        if (hint == 'Password' && !_isLoading) {
          _login();
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Color(0xFFD62828),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
