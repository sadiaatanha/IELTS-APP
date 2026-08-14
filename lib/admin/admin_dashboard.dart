import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login_page.dart';
import 'admin_reading_page.dart';
import 'admin_writing_page.dart';
import 'admin_speaking_page.dart';
import 'admin_listening_import_page.dart';
import 'admin_users_page.dart';
import 'admin_results_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  int totalUsers = 0;
  int totalAdmins = 0;
  int writingQuestions = 0;
  int readingQuestions = 0;
  int speakingTopics = 0;
  int listeningTests = 0;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final usersData = await supabase.from('profiles').select('id, role');
      final writingData = await supabase.from('writing_questions').select('id');
      final speakingData = await supabase.from('speaking_topics').select('id');
      final listeningData = await supabase.from('listening_tests').select('id');
      final readingData = await supabase.from('reading_passages').select('id');
    

      final usersList = List<Map<String, dynamic>>.from(usersData as List);
      final writingList = List<Map<String, dynamic>>.from(writingData as List);
      final speakingList = List<Map<String, dynamic>>.from(speakingData as List);
      final listeningList = List<Map<String, dynamic>>.from(listeningData as List);
      final readingList = List<Map<String, dynamic>>.from(readingData as List);

      if (!mounted) return;

      setState(() {
        totalUsers = usersList
            .where((user) => (user['role'] ?? 'user').toString() == 'user')
            .length;

        totalAdmins = usersList
            .where((user) => (user['role'] ?? 'user').toString() == 'admin')
            .length;

        writingQuestions = writingList.length;
        speakingTopics = speakingList.length;
        readingQuestions = readingList.length;
        listeningTests = listeningList.length;
      });
    } catch (e) {
      _showMessage("Dashboard load failed: ${e.toString()}");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: textColor),
        ),
        backgroundColor: const Color(0xFFE5E7EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: lightPrimary,
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: subTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: lightPrimary,
                  child: Icon(icon, color: primaryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 15,
                  color: subTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(
          Icons.logout,
          color: primaryColor,
          size: 20,
        ),
        label: const Text(
          "Logout",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
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
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 600 ? 520.0 : double.infinity;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, color: primaryColor),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Manage IELTSpire content, questions, users and results from here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.95,
                          children: [
                            _statCard(
                              title: "Writing",
                              value: writingQuestions,
                              icon: Icons.edit_note,
                              onTap: () => _openPage(
                                const AdminWritingPage(),
                              ),
                            ),
                            _statCard(
                              title: "Reading",
                              value: readingQuestions,
                              icon: Icons.menu_book_outlined,
                              onTap: () => _openPage(
                                const AdminReadingPage(),
                              ),
                            ),
                            _statCard(
                              title: "Speaking",
                              value: speakingTopics,
                              icon: Icons.mic_none,
                              onTap: () => _openPage(
                                const AdminSpeakingPage(),
                              ),
                            ),
                            _statCard(
                              title: listeningTests == 1
                                  ? "Listening Test"
                                  : "Listening Tests",
                              value: listeningTests,
                              icon: Icons.headphones_outlined,
                              onTap: () => _openPage(
                                const AdminListeningPage(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        const Text(
                          "Admin Actions",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _menuCard(
                          title: "View Admin Users",
                          subtitle: "View users and manage roles",
                          icon: Icons.people_outline,
                          onTap: () => _openPage(
                            const AdminUsersPage(initialFilter: 'All'),
                          ),
                        ),

                        _menuCard(
                          title: "View Results",
                          subtitle: "Check user test results and scores",
                          icon: Icons.bar_chart_outlined,
                          onTap: () => _openPage(
                            const AdminResultsPage(),
                          ),
                        ),

                        const SizedBox(height: 18),
                        _logoutButton(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}