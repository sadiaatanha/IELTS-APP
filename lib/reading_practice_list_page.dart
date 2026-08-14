import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reading_page.dart';

class ReadingPracticeListPage extends StatefulWidget {
  const ReadingPracticeListPage({super.key});

  @override
  State<ReadingPracticeListPage> createState() =>
      _ReadingPracticeListPageState();
}

class _ReadingPracticeListPageState extends State<ReadingPracticeListPage> {
  final supabase = Supabase.instance.client;

  static const Color primaryRed = Color(0xFFF44336);
  static const Color pageBackground = Color(0xFFFFF7FA);
  static const Color cardBackground = Color(0xFFFAF6FF);
  static const Color softRed = Color(0xFFFFCDD2);
  static const Color neutralBorder = Color(0xFFE7DDE7);
  static const Color textDark = Color(0xFF24212A);
  static const Color textGrey = Color(0xFF8B8790);

  bool isLoading = true;

  List<Map<String, dynamic>> passages = [];
  Map<String, int> questionCountByPassage = {};
  Set<String> completedPassageIds = {};

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryRed,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: pageBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _loadReadingPractices();
  }

  Future<void> _loadReadingPractices() async {
    setState(() => isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;

      final passageData = await supabase
          .from('reading_passages')
          .select()
          .eq('is_published', true)
          .order('passage_number', ascending: true);

      final questionData =
          await supabase.from('reading_questions').select('id, passage_id');

      final scoreData = userId == null
          ? []
          : await supabase
              .from('reading_scores')
              .select('passage_id')
              .eq('user_id', userId);

      final countMap = <String, int>{};

      for (final q in questionData as List) {
        final passageId = q['passage_id']?.toString();
        if (passageId != null) {
          countMap[passageId] = (countMap[passageId] ?? 0) + 1;
        }
      }

      final completedSet = <String>{};

      for (final score in List<Map<String, dynamic>>.from(scoreData)) {
        final passageId = score['passage_id']?.toString();
        if (passageId != null && passageId.isNotEmpty) {
          completedSet.add(passageId);
        }
      }

      setState(() {
        passages = List<Map<String, dynamic>>.from(passageData as List);
        questionCountByPassage = countMap;
        completedPassageIds = completedSet;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reading practices: $e')),
      );
    }
  }

  void _openReadingPractice(String passageId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPage(selectedPassageId: passageId),
      ),
    ).then((_) {
      _loadReadingPractices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = passages.length;
    final completed = completedPassageIds.length;
    final remaining = total - completed;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(
          'Reading Practice',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadReadingPractices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryRed),
            )
          : RefreshIndicator(
              onRefresh: _loadReadingPractices,
              color: primaryRed,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  _buildSummaryCard(
                    total: total,
                    completed: completed,
                    remaining: remaining,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Available Reading Tests',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (passages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          'No reading practices available.',
                          style: TextStyle(color: textGrey),
                        ),
                      ),
                    )
                  else
                    ...List.generate(passages.length, (index) {
                      final passage = passages[index];
                      final passageId = passage['id'].toString();
                      final isCompleted =
                          completedPassageIds.contains(passageId);

                      return _buildPracticeCard(
                        index: index,
                        passage: passage,
                        questionCount: questionCountByPassage[passageId] ?? 0,
                        isCompleted: isCompleted,
                        onTap: () => _openReadingPractice(passageId),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required int total,
    required int completed,
    required int remaining,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutralBorder),
      ),
      child: Row(
        children: [
          _summaryItem('Total', total.toString(), Icons.library_books),
          _summaryItem('Completed', completed.toString(), Icons.check_circle),
          _summaryItem('Left', remaining.toString(), Icons.pending_actions),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: softRed,
            child: Icon(
              icon,
              color: primaryRed,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: primaryRed,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: textGrey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeCard({
    required int index,
    required Map<String, dynamic> passage,
    required int questionCount,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    final title = passage['title']?.toString() ?? 'Untitled Passage';
    final difficulty = passage['difficulty']?.toString() ?? 'medium';
    final passageNumber = index + 1;
    final text = passage['passage_text']?.toString() ?? '';

    final preview = text.length > 120 ? '${text.substring(0, 120)}...' : text;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted ? Colors.green.shade300 : neutralBorder,
                width: 1.1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      isCompleted ? const Color(0xFFDCFCE7) : softRed,
                  child: Icon(
                    isCompleted ? Icons.check : Icons.menu_book_rounded,
                    color: isCompleted ? Colors.green.shade700 : primaryRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice Test $passageNumber',
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textGrey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tag(
                            text: difficulty.toUpperCase(),
                            color: Colors.orange.shade800,
                            borderColor: Colors.orange.shade200,
                            bg: const Color(0xFFFFF7ED),
                          ),
                          _tag(
                            text: '$questionCount Questions',
                            color: primaryRed,
                            borderColor: softRed,
                            bg: Colors.white,
                          ),
                          _tag(
                            text: isCompleted ? 'Completed' : 'Not Attempted',
                            color: isCompleted
                                ? Colors.green.shade800
                                : primaryRed,
                            borderColor:
                                isCompleted ? Colors.green.shade200 : softRed,
                            bg: isCompleted
                                ? const Color(0xFFDCFCE7)
                                : Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: primaryRed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag({
    required String text,
    required Color color,
    required Color borderColor,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
