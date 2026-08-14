import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/writing_question.dart';
import 'services/groq_service.dart';

// ─── Entry: Type Selection Screen ────────────────────────────────────────────

class WritingTestPage extends StatefulWidget {
  const WritingTestPage({super.key});

  @override
  State<WritingTestPage> createState() => _WritingTestPageState();
}

class _WritingTestPageState extends State<WritingTestPage> {
  String selectedTask1Type = 'bar';
  String selectedTask2Type = 'opinion';
  bool isLoading = false;

  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> task1Types = [
    {'value': 'bar', 'label': 'Bar Chart', 'icon': Icons.bar_chart},
    {'value': 'pie', 'label': 'Pie Chart', 'icon': Icons.pie_chart},
    {'value': 'line', 'label': 'Line Graph', 'icon': Icons.show_chart},
    {'value': 'table', 'label': 'Table', 'icon': Icons.table_chart},
    {
      'value': 'diagram',
      'label': 'Diagram',
      'icon': Icons.account_tree_outlined,
    },
    {'value': 'map', 'label': 'Map', 'icon': Icons.map_outlined},
    {'value': 'process', 'label': 'Process', 'icon': Icons.linear_scale},
    {'value': 'other', 'label': 'Other', 'icon': Icons.insert_chart},
  ];

  final List<Map<String, dynamic>> task2Types = [
    {'value': 'opinion', 'label': 'Opinion Essay'},
    {'value': 'discussion', 'label': 'Discussion'},
    {'value': 'problem-solution', 'label': 'Problem & Solution'},
    {
      'value': 'advantages-disadvantages',
      'label': 'Advantages & Disadvantages'
    },
    {'value': 'two-part', 'label': 'Two-Part Question'},
    {'value': 'other', 'label': 'Other'},
  ];

  Future<void> _startTest() async {
    setState(() => isLoading = true);

    try {
      final task1Data = await supabase
          .from('writing_questions')
          .select()
          .eq('task_type', 'task1')
          .eq('question_type', selectedTask1Type);

      final task2Data = await supabase
          .from('writing_questions')
          .select()
          .eq('task_type', 'task2')
          .eq('question_type', selectedTask2Type);

      if ((task1Data as List).isEmpty) {
        _showSnack(
          'No Task 1 questions found for "$selectedTask1Type". Try another type.',
        );
        setState(() => isLoading = false);
        return;
      }

      if ((task2Data as List).isEmpty) {
        _showSnack(
          'No Task 2 questions found for "$selectedTask2Type". Try another type.',
        );
        setState(() => isLoading = false);
        return;
      }

      task1Data.shuffle();
      task2Data.shuffle();

      final task1Q = WritingQuestion.fromMap(task1Data.first);
      final task2Q = WritingQuestion.fromMap(task2Data.first);

      if (!mounted) return;

      setState(() => isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _WritingTestExamPage(
            task1Question: task1Q,
            task2Question: task2Q,
          ),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack('Error loading questions: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F9),
      appBar: AppBar(
        title: const Text('Writing Test'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Writing Test',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '60 minutes · Task 1 + Task 2',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel(
              number: '1',
              title: 'Select Task 1 Type',
              subtitle: 'A random question of this type will be selected',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: task1Types.map((type) {
                final selected = selectedTask1Type == type['value'];

                return GestureDetector(
                  onTap: () => setState(() {
                    selectedTask1Type = type['value'];
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.red : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? Colors.red : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 18,
                          color: selected ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            _SectionLabel(
              number: '2',
              title: 'Select Task 2 Type',
              subtitle: 'A random question of this type will be selected',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: task2Types.map((type) {
                final selected = selectedTask2Type == type['value'];

                return GestureDetector(
                  onTap: () => setState(() {
                    selectedTask2Type = type['value'];
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.red : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? Colors.red : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      type['label'] as String,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _startTest,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  isLoading ? 'Loading Questions...' : 'Start Test',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Questions are fetched randomly from the question bank.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Screen ──────────────────────────────────────────────────────────────

class _WritingTestExamPage extends StatefulWidget {
  final WritingQuestion task1Question;
  final WritingQuestion task2Question;

  const _WritingTestExamPage({
    required this.task1Question,
    required this.task2Question,
  });

  @override
  State<_WritingTestExamPage> createState() => _WritingTestExamPageState();
}

class _WritingTestExamPageState extends State<_WritingTestExamPage> {
  final task1Controller = TextEditingController();
  final task2Controller = TextEditingController();

  Timer? timer;
  int secondsLeft = 3600;
  int secondsSpent = 0;

  bool submitted = false;
  bool isSaving = false;
  bool canType = true;

  double task1Band = 0.0;
  double task2Band = 0.0;
  double overallBandScore = 0.0;

  Map<String, dynamic>? task1FeedbackData;
  Map<String, dynamic>? task2FeedbackData;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || submitted) return;

      if (secondsLeft <= 0) {
        timer?.cancel();
        setState(() => canType = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time is up! Please submit now.')),
        );
      } else {
        setState(() {
          secondsLeft--;
          secondsSpent++;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    task1Controller.dispose();
    task2Controller.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _wordCount(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  Color get _timerColor {
    if (secondsLeft > 1200) return Colors.green;
    if (secondsLeft > 300) return Colors.orange;
    return Colors.red;
  }

  Future<void> _submitTest() async {
    final task1Answer = task1Controller.text.trim();
    final task2Answer = task2Controller.text.trim();

    if (task1Answer.isEmpty || task2Answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete both Task 1 and Task 2')),
      );
      return;
    }

    timer?.cancel();

    setState(() {
      isSaving = true;
      submitted = true;
      canType = false;
      task1FeedbackData = null;
      task2FeedbackData = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      final task1Feedback = await GroqService.checkWriting(
        module: 'writing_task_1',
        question: widget.task1Question.questionText,
        answer: task1Answer,
        imageUrl: widget.task1Question.imageUrl,
        chartType: widget.task1Question.questionType,
      );

      final task2Feedback = await GroqService.checkWriting(
        module: 'writing_task_2',
        question: widget.task2Question.questionText,
        answer: task2Answer,
        imageUrl: '',
        chartType: '',
      );

      final t1Band =
          double.tryParse(task1Feedback['band_score'].toString()) ?? 0.0;

      final t2Band =
          double.tryParse(task2Feedback['band_score'].toString()) ?? 0.0;

      // IELTS Writing Task 2 has double weight.
      // IELTS Writing Task 2 has double weight.
final rawOverall = (t1Band + (t2Band * 2)) / 3;

// Round to nearest IELTS band (0.5 steps)
final overall = (rawOverall * 2).round() / 2;

      await supabase.from('writing_test_results').insert({
        'user_id': userId,
        'task1_question_id': widget.task1Question.id,
        'task2_question_id': widget.task2Question.id,
        'task1_answer': task1Answer,
        'task2_answer': task2Answer,
        'task1_word_count': _wordCount(task1Answer),
        'task2_word_count': _wordCount(task2Answer),
        'time_spent_seconds': secondsSpent,
        'task1_band_score': t1Band,
        'task2_band_score': t2Band,
        'overall_band_score': overall,
        'task1_feedback': task1Feedback,
        'task2_feedback': task2Feedback,
      });

      await supabase.from('ielts_scores').insert({
        'user_id': userId,
        'module': 'writing',
        'band_score': overall,
        'created_at': DateTime.now().toIso8601String(),
      });

      await supabase.from('homepage_scores').insert({
        'user_id': userId,
        'module': 'writing',
        'band_score': overall,
        'test_type': 'full_test',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        task1Band = t1Band;
        task2Band = t2Band;
        overallBandScore = overall;
        task1FeedbackData = task1Feedback;
        task2FeedbackData = task2Feedback;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Writing test checked and saved!')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        submitted = false;
        canType = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI feedback failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t1Words = _wordCount(task1Controller.text);
    final t2Words = _wordCount(task2Controller.text);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F9),
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text('Writing Test'),
        leading: IconButton(
  icon: const Icon(Icons.arrow_back),
  onPressed: () {
    Navigator.pop(context);
  },
),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: _timerColor, size: 18),
                const SizedBox(width: 5),
                Text(
                  _formatTime(secondsLeft),
                  style: TextStyle(
                    color: _timerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
               color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _StatPill(
                    label: 'Task 1',
                    value: '$t1Words words',
                    color: t1Words >= 150 ? Colors.green : const Color.fromARGB(255, 244, 242, 240),
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: 'Task 2',
                    value: '$t2Words words',
                    color: t2Words >= 250 ? Colors.green : const Color.fromARGB(255, 244, 242, 240),
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: 'Spent',
                    value: _formatTime(secondsSpent),
                    color: const Color.fromARGB(255, 249, 250, 251),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _TaskBox(
              taskLabel: 'Task 1',
              question: widget.task1Question,
              controller: task1Controller,
              canType: canType,
              wordCount: t1Words,
              minWords: 150,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 22),
            _TaskBox(
              taskLabel: 'Task 2',
              question: widget.task2Question,
              controller: task2Controller,
              canType: canType,
              wordCount: t2Words,
              minWords: 250,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: submitted || isSaving ? null : _submitTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        submitted ? 'Submitted ✓' : 'Submit Test',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (submitted) ...[
              const SizedBox(height: 22),
              _ResultCard(
                isLoading: isSaving,
                t1Words: t1Words,
                t2Words: t2Words,
                timeSpent: secondsSpent,
                task1Band: task1Band,
                task2Band: task2Band,
                overallBandScore: overallBandScore,
                task1Feedback: task1FeedbackData,
                task2Feedback: task2FeedbackData,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Task Box ─────────────────────────────────────────────────────────────────

class _TaskBox extends StatelessWidget {
  final String taskLabel;
  final WritingQuestion question;
  final TextEditingController controller;
  final bool canType;
  final int wordCount;
  final int minWords;
  final VoidCallback onChanged;

  const _TaskBox({
    required this.taskLabel,
    required this.question,
    required this.controller,
    required this.canType,
    required this.wordCount,
    required this.minWords,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final meetsMin = wordCount >= minWords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  taskLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      meetsMin ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: meetsMin ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$wordCount / $minWords words',
                  style: TextStyle(
                    color: meetsMin ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (question.imageUrl.isNotEmpty) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 1000),
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
                      height: 140,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
                    );
                  },
                  errorBuilder: (ctx, err, _) => const SizedBox(
                    height: 80,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Text(
              question.questionText,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: canType,
            maxLines: 12,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText:
                  canType ? 'Write your answer here...' : 'Submission closed.',
              filled: true,
              fillColor: canType ? Colors.white : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade100),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Result Card ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final bool isLoading;
  final int t1Words;
  final int t2Words;
  final int timeSpent;
  final double task1Band;
  final double task2Band;
  final double overallBandScore;
  final Map<String, dynamic>? task1Feedback;
  final Map<String, dynamic>? task2Feedback;

  const _ResultCard({
    required this.isLoading,
    required this.t1Words,
    required this.t2Words,
    required this.timeSpent,
    required this.task1Band,
    required this.task2Band,
    required this.overallBandScore,
    required this.task1Feedback,
    required this.task2Feedback,
  });

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _text(Map<String, dynamic>? data, String key) {
    return data?[key]?.toString() ?? '';
  }

  Widget _feedbackText(String title, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tips(Map<String, dynamic>? data) {
    final tips = data?['improvement_tips'];

    if (tips is! List || tips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Improvement Tips',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $tip',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskFeedbackSection({
    required String title,
    required double band,
    required Map<String, dynamic>? feedback,
  }) {
    if (feedback == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 232, 101, 75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title Feedback • Band ${band.toStringAsFixed(1)}',
            style: const TextStyle(
              color: const Color(0xFFFFCDD2),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _feedbackText(
            'Overall Feedback',
            _text(feedback, 'overall_feedback'),
          ),
          _feedbackText(
            'Grammar',
            _text(feedback, 'grammar_feedback'),
          ),
          _feedbackText(
            'Vocabulary',
            _text(feedback, 'vocabulary_feedback'),
          ),
          _feedbackText(
            'Coherence',
            _text(feedback, 'coherence_feedback'),
          ),
          _tips(feedback),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color:  Colors.red,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text(
              'Groq is checking your full writing test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Writing Test Result',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryBox(
                title: 'Overall Estimated Band',
                value: overallBandScore.toStringAsFixed(1),
              ),
              const SizedBox(width: 10),
              _SummaryBox(
                title: 'Task 1',
                value: task1Band.toStringAsFixed(1),
              ),
              const SizedBox(width: 10),
              _SummaryBox(
                title: 'Task 2',
                value: task2Band.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryBox(title: 'Task 1 Words', value: '$t1Words'),
              const SizedBox(width: 10),
              _SummaryBox(title: 'Task 2 Words', value: '$t2Words'),
              const SizedBox(width: 10),
              _SummaryBox(title: 'Time', value: _formatTime(timeSpent)),
            ],
          ),
          _taskFeedbackSection(
            title: 'Task 1',
            band: task1Band,
            feedback: task1Feedback,
          ),
          _taskFeedbackSection(
            title: 'Task 2',
            band: task2Band,
            feedback: task2Feedback,
          ),
        ],
      ),
    );
  }
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.red,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 232, 101, 75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Color.fromARGB(135, 255, 255, 255),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color:const Color.fromARGB(255, 232, 101, 75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color.fromARGB(255, 236, 238, 239),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
