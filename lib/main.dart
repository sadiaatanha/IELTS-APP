import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'admin/admin_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ybbcsrngodpmtvyyrkou.supabase.co',
    anonKey: 'sb_publishable_Nh5Ohpo-Qi556xapPM8O3A_dP3xXbtU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartPage() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      return const LoginPage();
    }

    final user = session.user;

    if (user.emailConfirmedAt == null) {
      await supabase.auth.signOut();
      return const LoginPage();
    }

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final role = profile?['role']?.toString() ?? 'user';

    if (role == 'admin') {
      return const AdminDashboardPage();
    }

    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _getStartPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            );
          }

          if (snapshot.hasError) {
            return const LoginPage();
          }

          return snapshot.data ?? const LoginPage();
        },
      ),
    );
  }
}