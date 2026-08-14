import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/writing_question.dart';
import 'writing_answer_page.dart';

class WritingTask1Page extends StatefulWidget {
  const WritingTask1Page({super.key});

  @override
  State<WritingTask1Page> createState() => _WritingTask1PageState();
}

class _WritingTask1PageState extends State<WritingTask1Page> {
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
          .eq('task_type', 'task1')
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
      builder: (_) => _AddTask1QuestionSheet(
        onAdded: _fetchQuestions,
      ),
    );
  }

  Future<void> _deleteQuestion(WritingQuestion q) async {
    final userId = supabase.auth.currentUser?.id;
    if (q.userId == null || q.userId != userId) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
        title: const Text('Writing Task 1'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQuestions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddQuestionSheet,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Question',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
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
                      final isOwner = q.userId != null && q.userId == userId;
                      return _QuestionCard(
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
          Icon(Icons.bar_chart, size: 64, color: Colors.red.shade200),
          const SizedBox(height: 16),
          const Text('No Task 1 questions yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openAddQuestionSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Question',
                style: TextStyle(color: Colors.white)),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ─── Question Card ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final WritingQuestion question;
  final bool isOwner;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WritingAnswerPage(
            title: 'Writing Task 1',
            question: question.questionText,
            chartType: question.questionType,
            imageUrl: question.imageUrl,
            questionId: question.id,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (question.difficulty.isNotEmpty)
                    _DifficultyBadge(difficulty: question.difficulty),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 22),
                    ),
                  ],
                ],
              ),

              // User-added badge
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text('Added by you',
                        style:
                            TextStyle(fontSize: 11, color: Colors.blue)),
                  ),
                ),

              const SizedBox(height: 12),

              // Chart image
              if (question.imageUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 800),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      question.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 120,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, _) => const SizedBox(
                        height: 80,
                        child: Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.grey, size: 32),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              Text(
                question.questionText,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _TypeChip(type: question.questionType),
                  const Spacer(),
                  if (question.source.isNotEmpty)
                    Text(question.source,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Question Bottom Sheet ────────────────────────────────────────────────

class _AddTask1QuestionSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddTask1QuestionSheet({required this.onAdded});

  @override
  State<_AddTask1QuestionSheet> createState() =>
      _AddTask1QuestionSheetState();
}

class _AddTask1QuestionSheetState extends State<_AddTask1QuestionSheet> {
  final titleController = TextEditingController();
  final questionController = TextEditingController();
  final sourceController = TextEditingController();

  String selectedType = 'bar';
  String selectedDifficulty = 'medium';

  XFile? pickedImage;
  bool isSaving = false;

  final supabase = Supabase.instance.client;

  final List<String> chartTypes = [
    'bar', 'pie', 'line', 'table', 'diagram', 'map', 'process', 'other'
  ];
  final List<String> difficulties = ['easy', 'medium', 'hard'];

  @override
  void dispose() {
    titleController.dispose();
    questionController.dispose();
    sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) setState(() => pickedImage = image);
  }

  Future<String?> _uploadImage() async {
    if (pickedImage == null) return null;

    final userId = supabase.auth.currentUser?.id ?? 'unknown';
    final ext = pickedImage!.path.split('.').last;
    final path =
        'writing/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      if (kIsWeb) {
        final bytes = await pickedImage!.readAsBytes();
        await supabase.storage.from('writing-images').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        await supabase.storage.from('writing-images').upload(
              path,
              File(pickedImage!.path),
              fileOptions: const FileOptions(upsert: true),
            );
      }
      return supabase.storage.from('writing-images').getPublicUrl(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty ||
        questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and question text are required')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      final imageUrl = await _uploadImage();

      await supabase.from('writing_questions').insert({
        'task_type': 'task1',
        'question_type': selectedType,
        'title': titleController.text.trim(),
        'question_text': questionController.text.trim(),
        'image_url': imageUrl ?? '',
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
            // Handle bar
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

            const Text(
              'Add Task 1 Question',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Title
            _sheetField(
              controller: titleController,
              label: 'Title (e.g. Bar Chart Question)',
              icon: Icons.title,
            ),
            const SizedBox(height: 14),

            // Question text
            _sheetField(
              controller: questionController,
              label: 'Question Text',
              icon: Icons.help_outline,
              maxLines: 4,
            ),
            const SizedBox(height: 14),

            // Chart type dropdown
            _DropdownField(
              label: 'Chart Type',
              value: selectedType,
              items: chartTypes,
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),

            // Difficulty dropdown
            _DropdownField(
              label: 'Difficulty',
              value: selectedDifficulty,
              items: difficulties,
              onChanged: (v) => setState(() => selectedDifficulty = v!),
            ),
            const SizedBox(height: 14),

            // Source (optional)
            _sheetField(
              controller: sourceController,
              label: 'Source (optional)',
              icon: Icons.source_outlined,
            ),
            const SizedBox(height: 18),

            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: pickedImage != null ? null : 110,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.red.shade200, style: BorderStyle.solid),
                ),
                child: pickedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.red.shade300, size: 36),
                          const SizedBox(height: 8),
                          Text('Tap to upload chart image (optional)',
                              style: TextStyle(
                                  color: Colors.red.shade400, fontSize: 13)),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.network(pickedImage!.path,
                                    width: double.infinity,
                                    fit: BoxFit.cover)
                                : Image.file(File(pickedImage!.path),
                                    width: double.infinity,
                                    fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => pickedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(difficulty,
          style: TextStyle(
              color: _color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  IconData get _icon {
    switch (type.toLowerCase()) {
      case 'bar': return Icons.bar_chart;
      case 'pie': return Icons.pie_chart;
      case 'line': return Icons.show_chart;
      case 'table': return Icons.table_chart;
      case 'map': return Icons.map_outlined;
      case 'diagram': return Icons.account_tree_outlined;
      case 'process': return Icons.linear_scale;
      default: return Icons.insert_chart;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Text(
          '${type[0].toUpperCase()}${type.substring(1)}',
          style: const TextStyle(
              fontSize: 13,
              color: Colors.red,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}