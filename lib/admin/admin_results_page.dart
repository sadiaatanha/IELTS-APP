import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';




class AdminResultsPage extends StatefulWidget {
  const AdminResultsPage({super.key});

  @override
  State<AdminResultsPage> createState() => _AdminResultsPageState();
}

class _AdminResultsPageState extends State<AdminResultsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> speakingResults = [];
  List<Map<String, dynamic>> readingResults = [];
  List<Map<String, dynamic>> writingTestResults = [];
 List<Map<String, dynamic>> writingPracticeResults = [];
 List<Map<String, dynamic>> listeningResults = [];

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _fetchUsersWithResults();
  }

  Future<void> _fetchUsersWithResults() async {
    setState(() => isLoading = true);

    try {
      final speakingData = await supabase
          .from('speaking_results')
          .select()
          .order('created_at', ascending: false);

      final readingData = await supabase
          .from('reading_scores')
          .select()
          .order('created_at', ascending: false);
      final writingTestData = await supabase
    .from('writing_test_results')
    .select('''
      *,
      task1_question:writing_questions!writing_test_results_task1_question_id_fkey(title, question_text),
      task2_question:writing_questions!writing_test_results_task2_question_id_fkey(title, question_text)
    ''')
    .order('created_at', ascending: false);

   final writingPracticeData = await supabase
    .from('writing_practice_results')
    .select('*, question:writing_questions(title, question_text)')
    .order('created_at', ascending: false);

   final listeningData = await supabase
    .from('user_listening_attempts')
    .select('*, listening_tests(title)')
    .order('created_at', ascending: false);

writingTestResults = List<Map<String, dynamic>>.from(writingTestData);
writingPracticeResults = List<Map<String, dynamic>>.from(writingPracticeData);
listeningResults = List<Map<String, dynamic>>.from(listeningData);

      speakingResults = List<Map<String, dynamic>>.from(speakingData);
      readingResults = List<Map<String, dynamic>>.from(readingData);

      final userIds = [
  ...speakingResults.map((e) => e['user_id']?.toString()),
  ...readingResults.map((e) => e['user_id']?.toString()),
  ...writingTestResults.map((e) => e['user_id']?.toString()),
  ...writingPracticeResults.map((e) => e['user_id']?.toString()),
  ...listeningResults.map((e) => e['user_id']?.toString()),
].where((id) => id != null && id.isNotEmpty).toSet().toList();
      if (userIds.isEmpty) {
        setState(() {
          users = [];
          isLoading = false;
        });
        return;
      }

      final profilesData = await supabase
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .inFilter('id', userIds);

      users = List<Map<String, dynamic>>.from(profilesData);
    } catch (e) {
      _showMessage("Failed to load results: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  int _speakingCountForUser(String userId) {
    return speakingResults.where((r) => r['user_id'].toString() == userId).length;
  }

  int _readingCountForUser(String userId) {
    return readingResults.where((r) => r['user_id'].toString() == userId).length;
  }

  String _latestScoreForUser(String userId) {
    final userSpeaking = speakingResults
        .where((r) => r['user_id'].toString() == userId)
        .map((e) => {...e, 'type': 'speaking'})
        .toList();

    final userReading = readingResults
        .where((r) => r['user_id'].toString() == userId)
        .map((e) => {...e, 'type': 'reading'})
        .toList();

    final all = [...userSpeaking, ...userReading];

    if (all.isEmpty) return "-";

    all.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    final latest = all.first;

    if (latest['type'] == 'reading') {
      return latest['band_score']?.toString() ?? "-";
    }

    return latest['score']?.toString() ?? "-";
  }

  void _openUserDetails(Map<String, dynamic> user) {
    final userId = user['id'].toString();

    final userSpeakingResults =
        speakingResults.where((r) => r['user_id'].toString() == userId).toList();

    final userReadingResults =
        readingResults.where((r) => r['user_id'].toString() == userId).toList();
    final userWritingTests =
    writingTestResults.where((r) => r['user_id'].toString() == userId).toList();

   final userWritingPractice =
    writingPracticeResults.where((r) => r['user_id'].toString() == userId).toList();

    final userListeningResults =
    listeningResults.where((r) => r['user_id'].toString() == userId).toList();

    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AdminUserResultDetailsPage(
      user: user,
      speakingResults: userSpeakingResults,
      readingResults: userReadingResults,
      writingTestResults: userWritingTests,
      writingPracticeResults: userWritingPractice,
      listeningResults: userListeningResults,
    ),
  ),
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

  Widget _userCard(Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final name = user['full_name']?.toString().trim();
    final email = user['email']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString();

    
    final latestScore = _latestScoreForUser(userId);

    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openUserDetails(user),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: lightPrimary,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: !hasAvatar
                      ? const Icon(Icons.person, color: primaryColor)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty ? "Unknown User" : name,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: subTextColor),
                      ),
                      
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: lightPrimary,
                  child: Text(
                    latestScore,
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: subTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 55, color: primaryColor),
          SizedBox(height: 12),
          Text(
            "No users with results yet",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Users will appear here after saving results.",
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor),
          ),
        ],
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
        iconTheme: const IconThemeData(color: textColor),
        title: const Text(
          "Admin View Results",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchUsersWithResults,
            icon: const Icon(Icons.refresh, color: primaryColor),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final double contentWidth =
              (screenWidth * 0.35).clamp(300.0, 560.0).toDouble();

          return RefreshIndicator(
            onRefresh: _fetchUsersWithResults,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Users With Results (${users.length})",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      else if (users.isEmpty)
                        _emptyState()
                      else
                        ...users.map(_userCard),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminUserResultDetailsPage extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> speakingResults;
  final List<Map<String, dynamic>> readingResults;
  final List<Map<String, dynamic>> writingTestResults;
 final List<Map<String, dynamic>> writingPracticeResults;
 final List<Map<String, dynamic>> listeningResults;

  const AdminUserResultDetailsPage({
    super.key,
    required this.user,
    required this.speakingResults,
    required this.readingResults,
    required this.writingTestResults,
    required this.writingPracticeResults,
    required this.listeningResults,
  });

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: enabled ? Colors.white : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: enabled ? lightPrimary : Colors.grey.shade300,
                  child: Icon(
                    icon,
                    color: enabled ? primaryColor : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? textColor : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: enabled ? subTextColor : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.arrow_forward_ios : Icons.lock_outline,
                  size: 16,
                  color: enabled ? primaryColor : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = user['full_name']?.toString().trim();
    final email = user['email']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    final displayName = name == null || name.isEmpty ? "Unknown User" : name;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: const Text(
          "User Results",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.35)
                .clamp(300.0, 560.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: lightPrimary,
                        backgroundImage:
                            hasAvatar ? NetworkImage(avatarUrl) : null,
                        child: !hasAvatar
                            ? const Icon(Icons.person, color: primaryColor)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: subTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _moduleCard(
                  icon: Icons.mic,
                  title: "Speaking",
                  subtitle: "${speakingResults.length} results available",
                  enabled: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSpeakingResultOnlyPage(
                          userName: displayName,
                          speakingResults: speakingResults,
                        ),
                      ),
                    );
                  },
                ),
                _moduleCard(
                  icon: Icons.menu_book,
                  title: "Reading",
                  subtitle: "${readingResults.length} results available",
                  enabled: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminReadingResultOnlyPage(
                          userName: displayName,
                          readingResults: readingResults,
                        ),
                      ),
                    );
                  },
                ),
                _moduleCard(
  icon: Icons.edit,
  title: "Writing",
  subtitle:
      "${writingTestResults.length + writingPracticeResults.length} results available",
  enabled: true,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminWritingResultOnlyPage(
          userName: displayName,
          writingTestResults: writingTestResults,
          writingPracticeResults: writingPracticeResults,
        ),
      ),
    );
  },
),
                _moduleCard(
  icon: Icons.headphones,
  title: "Listening",
  subtitle: "${listeningResults.length} results available",
  enabled: true,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminListeningResultOnlyPage(
          userName: displayName,
          listeningResults: listeningResults,
        ),
      ),
    );
  },
),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSpeakingResultOnlyPage extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> speakingResults;

  const AdminSpeakingResultOnlyPage({
    super.key,
    required this.userName,
    required this.speakingResults,
  });

  @override
  State<AdminSpeakingResultOnlyPage> createState() =>
      _AdminSpeakingResultOnlyPageState();
}

class _AdminSpeakingResultOnlyPageState
    extends State<AdminSpeakingResultOnlyPage> {
  final supabase = Supabase.instance.client;

  late List<Map<String, dynamic>> speakingResults;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    speakingResults = List.from(widget.speakingResults);
  }

  String _safeText(dynamic value) {
    if (value == null) return "N/A";
    if (value.toString().trim().isEmpty) return "N/A";
    return value.toString();
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteSpeakingResult(String id) async {
    final confirm = await _confirmDelete(
      title: "Delete Speaking Result?",
      message: "This speaking result will be permanently deleted.",
    );

    if (!confirm) return;

    await supabase.from('speaking_results').delete().eq('id', id);

    setState(() {
      speakingResults.removeWhere((e) => e['id'] == id);
    });
  }

  Future<void> _deleteAllSpeakingResults() async {
    final confirm = await _confirmDelete(
      title: "Delete All Speaking Results?",
      message: "All speaking results of this user will be permanently deleted.",
    );

    if (!confirm) return;

    for (final item in speakingResults) {
      await supabase.from('speaking_results').delete().eq('id', item['id']);
    }

    setState(() {
      speakingResults.clear();
    });
  }

  Widget _smallScoreBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$title: $value",
        style: const TextStyle(
          color: primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _speakingResultCard(Map<String, dynamic> item) {
    final part = _safeText(item['part']);
    final topic = _safeText(item['topic']);
    final transcript = _safeText(item['transcript']);
    final feedback = _safeText(item['feedback']);
    final score = _safeText(item['score']);
    final fluency = _safeText(item['fluency']);
    final vocabulary = _safeText(item['vocabulary']);
    final grammar = _safeText(item['grammar']);
    final pronunciation = _safeText(item['pronunciation']);
    final date = item['created_at']?.toString().split('T').first ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: lightPrimary,
                child: Text(
                  score,
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  part,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                date,
                style: const TextStyle(color: subTextColor, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: primaryColor),
                onPressed: () => _deleteSpeakingResult(item['id']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Topic: $topic",
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallScoreBox("Fluency", fluency),
              _smallScoreBox("Vocabulary", vocabulary),
              _smallScoreBox("Grammar", grammar),
              _smallScoreBox("Pronunciation", pronunciation),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Transcript",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            transcript,
            style: const TextStyle(color: subTextColor, height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text(
            "Feedback",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            feedback,
            style: const TextStyle(
              color: primaryColor,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 55, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double contentWidth =
        (MediaQuery.of(context).size.width * 0.35).clamp(300.0, 560.0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: Text(
          "${widget.userName} Speaking Results",
          style: const TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (speakingResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: primaryColor),
              onPressed: _deleteAllSpeakingResults,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: speakingResults.isEmpty
                ? _emptyBox("No speaking results found", Icons.mic_none)
                : Column(
                    children: speakingResults.map(_speakingResultCard).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}

class AdminReadingResultOnlyPage extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> readingResults;

  const AdminReadingResultOnlyPage({
    super.key,
    required this.userName,
    required this.readingResults,
  });

  @override
  State<AdminReadingResultOnlyPage> createState() =>
      _AdminReadingResultOnlyPageState();
}

class _AdminReadingResultOnlyPageState
    extends State<AdminReadingResultOnlyPage> {
  final supabase = Supabase.instance.client;

  late List<Map<String, dynamic>> readingResults;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    readingResults = List.from(widget.readingResults);
  }

  String _safeText(dynamic value) {
    if (value == null) return "N/A";
    if (value.toString().trim().isEmpty) return "N/A";
    return value.toString();
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteReadingResult(String id) async {
    final confirm = await _confirmDelete(
      title: "Delete Reading Result?",
      message: "This reading result will be permanently deleted.",
    );

    if (!confirm) return;

    await supabase.from('reading_scores').delete().eq('id', id);

    setState(() {
      readingResults.removeWhere((e) => e['id'] == id);
    });
  }

  Future<void> _deleteAllReadingResults() async {
    final confirm = await _confirmDelete(
      title: "Delete All Reading Results?",
      message: "All reading results of this user will be permanently deleted.",
    );

    if (!confirm) return;

    for (final item in readingResults) {
      await supabase.from('reading_scores').delete().eq('id', item['id']);
    }

    setState(() {
      readingResults.clear();
    });
  }

  Widget _readingResultCard(Map<String, dynamic> item) {
    final practiceType = _safeText(item['practice_type']);
    final correctAnswers = _safeText(item['correct_answers']);
    final totalQuestions = _safeText(item['total_questions']);
    final percentage = _safeText(item['percentage']);
    final bandScore = _safeText(item['band_score']);
    final insight = _safeText(item['insight']);
    final date = item['created_at']?.toString().split('T').first ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: lightPrimary,
                child: Text(
                  bandScore,
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Reading - $practiceType",
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                date,
                style: const TextStyle(color: subTextColor, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: primaryColor),
                onPressed: () => _deleteReadingResult(item['id']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Score: $correctAnswers / $totalQuestions",
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Accuracy: $percentage%",
            style: const TextStyle(color: subTextColor),
          ),
          const SizedBox(height: 12),
          const Text(
            "Insight",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            insight,
            style: const TextStyle(
              color: primaryColor,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 55, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double contentWidth =
        (MediaQuery.of(context).size.width * 0.35).clamp(300.0, 560.0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: Text(
          "${widget.userName} Reading Results",
          style: const TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (readingResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: primaryColor),
              onPressed: _deleteAllReadingResults,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: readingResults.isEmpty
                ? _emptyBox("No reading results found", Icons.menu_book)
                : Column(
                    children: readingResults.map(_readingResultCard).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}

class AdminWritingResultOnlyPage extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> writingTestResults;
  final List<Map<String, dynamic>> writingPracticeResults;

  const AdminWritingResultOnlyPage({
    super.key,
    required this.userName,
    required this.writingTestResults,
    required this.writingPracticeResults,
  });

  @override
  State<AdminWritingResultOnlyPage> createState() =>
      _AdminWritingResultOnlyPageState();
}

class _AdminWritingResultOnlyPageState extends State<AdminWritingResultOnlyPage> {
  final supabase = Supabase.instance.client;
  Future<bool> _confirmDelete({
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  return result == true;
}

  late List<Map<String, dynamic>> testResults;
  late List<Map<String, dynamic>> practiceResults;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    testResults = List.from(widget.writingTestResults);
    practiceResults = List.from(widget.writingPracticeResults);
  }

  String _safe(dynamic v) =>
      v == null || v.toString().trim().isEmpty ? "N/A" : v.toString();

  Future<void> _deleteTestResult(String id) async {
  final confirm = await _confirmDelete(
    title: "Delete Writing Test Result?",
    message: "This full writing test result will be permanently deleted.",
  );

  if (!confirm) return;

  await supabase.from('writing_test_results').delete().eq('id', id);
  setState(() => testResults.removeWhere((e) => e['id'] == id));
}

  Future<void> _deletePracticeResult(String id) async {
  final confirm = await _confirmDelete(
    title: "Delete Writing Practice Result?",
    message: "This writing practice result will be permanently deleted.",
  );

  if (!confirm) return;

  await supabase.from('writing_practice_results').delete().eq('id', id);
  setState(() => practiceResults.removeWhere((e) => e['id'] == id));
}

Future<void> _deleteAllWritingResults() async {
  final confirm = await _confirmDelete(
    title: "Delete All Writing Results?",
    message: "All writing results of this user will be permanently deleted.",
  );

  if (!confirm) return;

  for (final item in testResults) {
    await supabase.from('writing_test_results').delete().eq('id', item['id']);
  }

  for (final item in practiceResults) {
    await supabase.from('writing_practice_results').delete().eq('id', item['id']);
  }

  setState(() {
    testResults.clear();
    practiceResults.clear();
  });
}
  Widget _resultCard({
    required String title,
    required String date,
    required String score,
    required String question,
    required String answer,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: lightPrimary,
                child: Text(score,
                    style: const TextStyle(
                        color: primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: primaryColor),
                onPressed: onDelete,
              ),
            ],
          ),
          Text(date, style: const TextStyle(color: subTextColor, fontSize: 12)),
          const SizedBox(height: 12),
          const Text("Question",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(question, style: const TextStyle(color: subTextColor, height: 1.5)),
          const SizedBox(height: 12),
          const Text("User Answer",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(answer, style: const TextStyle(color: subTextColor, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = testResults.length + practiceResults.length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: Text("${widget.userName} Writing Results",
            style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          if (total > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: primaryColor),
              onPressed: _deleteAllWritingResults,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.35).clamp(300.0, 560.0),
            child: total == 0
                ? const Text("No writing results found")
                : Column(
                    children: [
                      ...testResults.map((item) {
                        final date =
                            item['created_at']?.toString().split('T').first ?? '';
                        return Column(
                          children: [
                            _resultCard(
                              title: "Writing Full Test - Task 1",
                              date: date,
                              score: _safe(item['task1_band_score']),
                              question: _safe(item['task1_question']?['question_text']),
                              answer: _safe(item['task1_answer']),
                              onDelete: () => _deleteTestResult(item['id']),
                            ),
                            _resultCard(
                              title: "Writing Full Test - Task 2",
                              date: date,
                              score: _safe(item['task2_band_score']),
                              question: _safe(item['task2_question']?['question_text']),
                              answer: _safe(item['task2_answer']),
                              onDelete: () => _deleteTestResult(item['id']),
                            ),
                          ],
                        );
                      }),
                      ...practiceResults.map((item) {
                        final date =
                            item['created_at']?.toString().split('T').first ?? '';
                        return _resultCard(
                          title: "Writing Practice - ${_safe(item['task_type'])}",
                          date: date,
                          score: _safe(item['band_score']),
                          question: _safe(item['question_text']),
                          answer: _safe(item['answer']),
                          onDelete: () => _deletePracticeResult(item['id']),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AdminListeningResultOnlyPage extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> listeningResults;

  const AdminListeningResultOnlyPage({
    super.key,
    required this.userName,
    required this.listeningResults,
  });

  @override
  State<AdminListeningResultOnlyPage> createState() =>
      _AdminListeningResultOnlyPageState();
}

class _AdminListeningResultOnlyPageState
    extends State<AdminListeningResultOnlyPage> {
  final supabase = Supabase.instance.client;
  Future<bool> _confirmDelete({
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  return result == true;
}

  late List<Map<String, dynamic>> results;

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    results = List.from(widget.listeningResults);
  }

  String _safe(dynamic v) =>
      v == null || v.toString().trim().isEmpty ? "N/A" : v.toString();

  Future<void> _deleteListeningResult(String id) async {
  final confirm = await _confirmDelete(
    title: "Delete Listening Result?",
    message: "This listening result will be permanently deleted.",
  );

  if (!confirm) return;

  await supabase.from('user_listening_attempts').delete().eq('id', id);
  setState(() => results.removeWhere((e) => e['id'] == id));
}

Future<void> _deleteAllListeningResults() async {
  final confirm = await _confirmDelete(
    title: "Delete All Listening Results?",
    message: "All listening results of this user will be permanently deleted.",
  );

  if (!confirm) return;

  for (final item in results) {
    await supabase.from('user_listening_attempts').delete().eq('id', item['id']);
  }

  setState(() => results.clear());
}

  Widget _listeningCard(Map<String, dynamic> item) {
    final testName = item['listening_tests']?['title'] ?? "Listening Test";
    final score = _safe(item['score']);
    final total = _safe(item['total']);
    final band = _safe(item['band_score']);
    final date = item['created_at']?.toString().split('T').first ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: lightPrimary,
            child: Text(band,
                style: const TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_safe(testName),
                    style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 6),
                Text("Score: $score / $total",
                    style: const TextStyle(color: subTextColor)),
                const SizedBox(height: 4),
                Text(date,
                    style: const TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: primaryColor),
            onPressed: () => _deleteListeningResult(item['id']),
          ),
        ],
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
        iconTheme: const IconThemeData(color: textColor),
        title: Text("${widget.userName} Listening Results",
            style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          if (results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: primaryColor),
              onPressed: _deleteAllListeningResults,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.35).clamp(300.0, 560.0),
            child: results.isEmpty
                ? const Text("No listening results found")
                : Column(children: results.map(_listeningCard).toList()),
          ),
        ),
      ),
    );
  }
}