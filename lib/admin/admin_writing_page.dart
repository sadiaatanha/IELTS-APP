import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWritingPage extends StatefulWidget {
  const AdminWritingPage({super.key});

  @override
  State<AdminWritingPage> createState() => _AdminWritingPageState();
}

class _AdminWritingPageState extends State<AdminWritingPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController tabController;
  bool isLoading = true;

  List<Map<String, dynamic>> task1Questions = [];
  List<Map<String, dynamic>> task2Questions = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
  setState(() => isLoading = true);

  try {
    final task1 = await supabase
        .from('writing_questions')
        .select()
        .eq('task_type', 'task1')
        .order('created_at', ascending: false);

    final task2 = await supabase
        .from('writing_questions')
        .select()
        .eq('task_type', 'task2')
        .order('created_at', ascending: false);

    setState(() {
      task1Questions = List<Map<String, dynamic>>.from(task1);
      task2Questions = List<Map<String, dynamic>>.from(task2);
      isLoading = false;
    });
  } catch (e) {
    setState(() => isLoading = false);
    showMsg('Failed to load questions: $e');
  }
}

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> deleteQuestion(String id) async {
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('writing_questions').delete().eq('id', id);
      showMsg('Question deleted');
      fetchQuestions();
    } catch (e) {
      showMsg('Delete failed: $e');
    }
  }

  void openQuestionSheet({
    required String taskType,
    Map<String, dynamic>? question,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _AdminWritingQuestionSheet(
        taskType: taskType,
        oldQuestion: question,
        onSaved: fetchQuestions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F9),
      appBar: AppBar(
        title: const Text('Admin Writing'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Task 1'),
            Tab(text: 'Task 2'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: fetchQuestions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: tabController,
              children: [
                _buildQuestionList('task1', task1Questions),
                _buildQuestionList('task2', task2Questions),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Question',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          final taskType = tabController.index == 0 ? 'task1' : 'task2';
          openQuestionSheet(taskType: taskType);
        },
      ),
    );
  }

  Widget _buildQuestionList(String taskType, List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          taskType == 'task1'
              ? 'No public Task 1 questions yet.'
              : 'No public Task 2 questions yet.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final q = list[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          openQuestionSheet(taskType: taskType, question: q),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteQuestion(q['id']),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q['question_text'] ?? '',
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip(q['question_type'] ?? ''),
                    _chip(q['difficulty'] ?? ''),
                    _chip(q['user_id'] == null ? 'Public' : 'User Private'),
                  ],
                ),
                if ((q['image_url'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      q['image_url'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Chip(
      label: Text(text),
      backgroundColor: Colors.red.shade50,
      labelStyle: const TextStyle(color: Colors.red),
    );
  }
}

class _AdminWritingQuestionSheet extends StatefulWidget {
  final String taskType;
  final Map<String, dynamic>? oldQuestion;
  final VoidCallback onSaved;

  const _AdminWritingQuestionSheet({
    required this.taskType,
    required this.onSaved,
    this.oldQuestion,
  });

  @override
  State<_AdminWritingQuestionSheet> createState() =>
      _AdminWritingQuestionSheetState();
}

class _AdminWritingQuestionSheetState
    extends State<_AdminWritingQuestionSheet> {
  final supabase = Supabase.instance.client;

  final titleController = TextEditingController();
  final questionController = TextEditingController();
  final sourceController = TextEditingController();

  String selectedType = 'bar';
  String selectedDifficulty = 'medium';

  XFile? pickedImage;
  String oldImageUrl = '';
  bool isSaving = false;

  final task1Types = [
    'bar',
    'pie',
    'line',
    'table',
    'diagram',
    'map',
    'process',
    'other'
  ];

  final task2Types = [
    'opinion',
    'discussion',
    'problem-solution',
    'advantages-disadvantages',
    'two-part',
    'other'
  ];

  final difficulties = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();

    final q = widget.oldQuestion;

    if (q != null) {
      titleController.text = q['title'] ?? '';
      questionController.text = q['question_text'] ?? '';
      sourceController.text = q['source'] ?? '';
      selectedType = q['question_type'] ?? _defaultType;
      selectedDifficulty = q['difficulty'] ?? 'medium';
      oldImageUrl = q['image_url'] ?? '';
    } else {
      selectedType = _defaultType;
    }
  }

  String get _defaultType => widget.taskType == 'task1' ? 'bar' : 'opinion';

  @override
  void dispose() {
    titleController.dispose();
    questionController.dispose();
    sourceController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      setState(() => pickedImage = image);
    }
  }

  Future<String?> uploadImage() async {
    if (pickedImage == null) return oldImageUrl;

    final userId = supabase.auth.currentUser?.id ?? 'admin';
    final ext = pickedImage!.path.split('.').last;
    final path =
        'writing/admin/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

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
  }

  Future<void> saveQuestion() async {
    if (titleController.text.trim().isEmpty ||
        questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and question text are required')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final imageUrl = await uploadImage();

      final data = {
        'task_type': widget.taskType,
        'question_type': selectedType,
        'title': titleController.text.trim(),
        'question_text': questionController.text.trim(),
        'image_url': imageUrl ?? '',
        'difficulty': selectedDifficulty,
        'source': sourceController.text.trim().isEmpty
            ? 'Admin'
            : sourceController.text.trim(),
        'user_id': null,
      };

      if (widget.oldQuestion == null) {
        await supabase.from('writing_questions').insert(data);
      } else {
        await supabase
            .from('writing_questions')
            .update(data)
            .eq('id', widget.oldQuestion!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.oldQuestion == null
                ? 'Question added'
                : 'Question updated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }

    if (mounted) setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTask1 = widget.taskType == 'task1';
    final types = isTask1 ? task1Types : task2Types;

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
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.oldQuestion == null
                  ? 'Add ${isTask1 ? "Task 1" : "Task 2"} Question'
                  : 'Update ${isTask1 ? "Task 1" : "Task 2"} Question',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _field(
              controller: titleController,
              label: 'Title',
              icon: Icons.title,
            ),
            const SizedBox(height: 14),

            _field(
              controller: questionController,
              label: 'Question Text',
              icon: Icons.help_outline,
              maxLines: 5,
            ),
            const SizedBox(height: 14),

            _dropdown(
              label: isTask1 ? 'Chart Type' : 'Question Type',
              value: selectedType,
              items: types,
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),

            _dropdown(
              label: 'Difficulty',
              value: selectedDifficulty,
              items: difficulties,
              onChanged: (v) => setState(() => selectedDifficulty = v!),
            ),
            const SizedBox(height: 14),

            _field(
              controller: sourceController,
              label: 'Source',
              icon: Icons.source_outlined,
            ),

            if (isTask1) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Center(
                    child: pickedImage != null
                        ? const Text('New image selected')
                        : oldImageUrl.isNotEmpty
                            ? const Text('Tap to change current image')
                            : const Text('Tap to upload image optional'),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.oldQuestion == null
                            ? 'Save Question'
                            : 'Update Question',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text('${e[0].toUpperCase()}${e.substring(1)}'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}