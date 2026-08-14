import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/writing_question.dart';
import 'writing_answer_page.dart';

class WritingTask2Page extends StatefulWidget {
  const WritingTask2Page({super.key});

  @override
  State<WritingTask2Page> createState() => _WritingTask2PageState();
}

class _WritingTask2PageState extends State<WritingTask2Page> {
  bool isLoading = true;
  List<WritingQuestion> questions = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('writing_questions')
          .select()
          .eq('task_type', 'task2')
          .order('created_at', ascending: true);

      setState(() {
        questions = (data as List)
            .map((item) => WritingQuestion.fromMap(item))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  void _openAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddTask2QuestionSheet(onAdded: _fetchQuestions),
    );
  }

  Future<void> _deleteQuestion(WritingQuestion q) async {
    final userId = supabase.auth.currentUser?.id;
    if (q.userId == null || q.userId != userId) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content:
            const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('writing_questions').delete().eq('id', q.id);
      _fetchQuestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F9),
      appBar: AppBar(
        title: const Text('Writing Task 2'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _fetchQuestions),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddQuestionSheet,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Question',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.red))
          : questions.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchQuestions,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(18, 18, 18, 100),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final isOwner =
                          q.userId != null && q.userId == userId;
                      return _QuestionCard(
                        index: index,
                        question: q,
                        isOwner: isOwner,
                        onDelete: () => _deleteQuestion(q),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 64, color: Colors.red.shade200),
          const SizedBox(height: 16),
          const Text('No Task 2 questions yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openAddQuestionSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Question',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ─── Question Card ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int index;
  final WritingQuestion question;
  final bool isOwner;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WritingAnswerPage(
            title: 'Writing Task 2',
            question: question.questionText,
            chartType: '',
            imageUrl: '',
            questionId: question.id,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.red.shade100,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(question.title,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    Text(
                      question.questionText,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (question.difficulty.isNotEmpty)
                          _DifficultyBadge(
                              difficulty: question.difficulty),
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.blue.shade200),
                            ),
                            child: const Text('Added by you',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.blue)),
                          ),
                        ],
                        const Spacer(),
                        if (isOwner)
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Question Bottom Sheet ────────────────────────────────────────────────

class _AddTask2QuestionSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddTask2QuestionSheet({required this.onAdded});

  @override
  State<_AddTask2QuestionSheet> createState() =>
      _AddTask2QuestionSheetState();
}

class _AddTask2QuestionSheetState extends State<_AddTask2QuestionSheet> {
  final titleController = TextEditingController();
  final questionController = TextEditingController();
  final sourceController = TextEditingController();

  String selectedType = 'opinion';
  String selectedDifficulty = 'medium';
  bool isSaving = false;

  final supabase = Supabase.instance.client;

  final List<String> questionTypes = [
    'opinion', 'discussion', 'problem-solution',
    'advantages-disadvantages', 'two-part', 'other'
  ];
  final List<String> difficulties = ['easy', 'medium', 'hard'];

  @override
  void dispose() {
    titleController.dispose();
    questionController.dispose();
    sourceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty ||
        questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Title and question text are required')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;

      await supabase.from('writing_questions').insert({
        'task_type': 'task2',
        'question_type': selectedType,
        'title': titleController.text.trim(),
        'question_text': questionController.text.trim(),
        'image_url': '',
        'difficulty': selectedDifficulty,
        'source': sourceController.text.trim(),
        'user_id': userId,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Add Task 2 Question',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _sheetField(
              controller: titleController,
              label: 'Title (e.g. Opinion Essay)',
              icon: Icons.title,
            ),
            const SizedBox(height: 14),

            _sheetField(
              controller: questionController,
              label: 'Question Text',
              icon: Icons.help_outline,
              maxLines: 4,
            ),
            const SizedBox(height: 14),

            _DropdownField(
              label: 'Question Type',
              value: selectedType,
              items: questionTypes,
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),

            _DropdownField(
              label: 'Difficulty',
              value: selectedDifficulty,
              items: difficulties,
              onChanged: (v) => setState(() => selectedDifficulty = v!),
            ),
            const SizedBox(height: 14),

            _sheetField(
              controller: sourceController,
              label: 'Source (optional)',
              icon: Icons.source_outlined,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Question',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red),
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(
                  '${e[0].toUpperCase()}${e.substring(1)}')))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  Color get _color {
    switch (difficulty.toLowerCase()) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'hard': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(difficulty,
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}