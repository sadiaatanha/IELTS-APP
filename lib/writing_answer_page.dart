import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/groq_service.dart';

class WritingAnswerPage extends StatefulWidget {
  final String title;
  final String question;
  final String chartType;
  final String imageUrl;
  final String questionId;

  const WritingAnswerPage({
    super.key,
    required this.title,
    required this.question,
    required this.chartType,
    required this.imageUrl,
    required this.questionId,
  });

  @override
  State<WritingAnswerPage> createState() => _WritingAnswerPageState();
}

class _WritingAnswerPageState extends State<WritingAnswerPage> {
  final answerController = TextEditingController();
  final supabase = Supabase.instance.client;

  Timer? timer;
  int secondsSpent = 0;

  bool submitted = false;
  bool isChecking = false;

  Map<String, dynamic>? feedbackData;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !submitted) {
        setState(() => secondsSpent++);
      }
    });
  }

  String formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get wordCount {
    final text = answerController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  bool get hasChart =>
      widget.chartType.isNotEmpty && widget.imageUrl.isNotEmpty;

  String get taskType {
    return widget.title.toLowerCase().contains('task 1') ? 'task1' : 'task2';
  }

  Future<void> submitWriting() async {
    final answer = answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your answer first')),
      );
      return;
    }

    timer?.cancel();

    setState(() {
      isChecking = true;
      submitted = true;
      feedbackData = null;
    });

    try {
      final parsedFeedback = await GroqService.checkWriting(
        module: taskType == 'task1' ? 'writing_task_1' : 'writing_task_2',
        question: widget.question,
        answer: answer,
        imageUrl: widget.imageUrl,
        chartType: widget.chartType,
      );

      final band =
          double.tryParse(parsedFeedback['band_score'].toString()) ?? 0.0;

      final user = supabase.auth.currentUser;

      await supabase.from('writing_practice_results').insert({
        'user_id': user?.id,
        'question_id': widget.questionId.isEmpty ? null : widget.questionId,
        'task_type': taskType,
        'question_text': widget.question,
        'image_url': widget.imageUrl,
        'answer': answer,
        'word_count': wordCount,
        'time_spent_seconds': secondsSpent,
        'band_score': band,
        'feedback': parsedFeedback,
      });
      await supabase.from('ielts_scores').insert({
        'user_id': user?.id,
        'module': 'writing',
        'band_score': band,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        feedbackData = parsedFeedback;
        isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Writing checked successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI feedback failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tips = feedbackData?['improvement_tips'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F7),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasChart) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 1000),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 140,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text('Chart image could not be loaded'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                widget.question,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time: ${formatTime(secondsSpent)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Words: $wordCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: answerController,
              enabled: !submitted,
              maxLines: 16,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Write your answer here...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: submitted || isChecking ? null : submitWriting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isChecking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        submitted ? 'Submitted' : 'Submit Writing',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (submitted) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isChecking
                    ? const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Groq is checking your writing...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : feedbackData == null
                        ? const Text(
                            'No feedback available.',
                            style: TextStyle(color: Colors.white),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Writing Feedback',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _StatBox(
                                    title: 'Estimated Band',
                                    value:
                                        feedbackData!['band_score'].toString(),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatBox(title: 'Words', value: '$wordCount'),
                                  const SizedBox(width: 10),
                                  _StatBox(
                                    title: 'Time',
                                    value: formatTime(secondsSpent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _FeedbackText(
                                title: 'Overall Feedback',
                                text: feedbackData!['overall_feedback'] ?? '',
                              ),
                              _FeedbackText(
                                title: 'Grammar',
                                text: feedbackData!['grammar_feedback'] ?? '',
                              ),
                              _FeedbackText(
                                title: 'Vocabulary',
                                text:
                                    feedbackData!['vocabulary_feedback'] ?? '',
                              ),
                              _FeedbackText(
                                title: 'Coherence',
                                text: feedbackData!['coherence_feedback'] ?? '',
                              ),
                              if (tips is List) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Improvement Tips',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                            ],
                          ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;

  const _StatBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 224, 50, 50),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color.fromARGB(255, 248, 251, 252),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackText extends StatelessWidget {
  final String title;
  final String text;

  const _FeedbackText({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

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
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
