import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/groq_service.dart';

class AdminReadingPage extends StatefulWidget {
  const AdminReadingPage({super.key});

  @override
  State<AdminReadingPage> createState() => _AdminReadingPageState();
}

class _AdminReadingPageState extends State<AdminReadingPage> {
  final supabase = Supabase.instance.client;

  static const Color primaryRed = Color(0xFFF44336);
  static const Color pageBackground = Color(0xFFFFF7FA);
  static const Color cardBackground = Color(0xFFFAF6FF);
  static const Color neutralBorder = Color(0xFFE7DDE7);
  static const Color textDark = Color(0xFF24212A);
  static const Color textGrey = Color(0xFF8B8790);

  final titleController = TextEditingController();
  final passageController = TextEditingController();
  final sourceController = TextEditingController(text: 'Admin / AI');

  final questionController = TextEditingController();
  final answerController = TextEditingController();
  final explanationController = TextEditingController();

  final option1Controller = TextEditingController();
  final option2Controller = TextEditingController();
  final option3Controller = TextEditingController();
  final option4Controller = TextEditingController();

  String difficulty = 'medium';
  String questionType = 'MCQ';
  bool isLoading = false;

  String? savedPassageId;
  List<Map<String, dynamic>> generatedQuestions = [];
  List<Map<String, dynamic>> savedQuestions = [];
  List<Map<String, dynamic>> savedPassages = [];

  final questionTypes = const [
    'MCQ',
    'fill_blank',
    'true_false_not_given',
    'matching_heading',
    'matching_information',
    'short_answer',
  ];
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

    _fetchSavedPassages();
  }

  @override
  void dispose() {
    titleController.dispose();
    passageController.dispose();
    sourceController.dispose();
    questionController.dispose();
    answerController.dispose();
    explanationController.dispose();
    option1Controller.dispose();
    option2Controller.dispose();
    option3Controller.dispose();
    option4Controller.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _normalType(String type) {
    final t = type.trim().toLowerCase();
    if (t.contains('mcq')) return 'MCQ';
    if (t == 'fill_blank') return 'fill_blank';
    if (t == 'true_false_not_given') return 'true_false_not_given';
    if (t == 'matching_heading') return 'matching_heading';
    if (t == 'matching_information') return 'matching_information';
    if (t == 'short_answer') return 'short_answer';
    return type.trim();
  }

  bool _hasOptions(String type) {
    final t = type.trim().toLowerCase();
    return t.contains('mcq') ||
        t == 'matching_heading' ||
        t == 'matching_information';
  }

  Future<void> _savePassage() async {
    if (titleController.text.trim().isEmpty ||
        passageController.text.trim().isEmpty) {
      _msg('Title and passage required');
      return;
    }

    setState(() => isLoading = true);

    try {
      final lastPassage = await supabase
          .from('reading_passages')
          .select('passage_number')
          .order('passage_number', ascending: false)
          .limit(1);

      final nextPassageNumber = lastPassage.isEmpty
          ? 1
          : (lastPassage[0]['passage_number'] as int) + 1;

      final inserted = await supabase
          .from('reading_passages')
          .insert({
            'title': titleController.text.trim(),
            'passage_text': passageController.text.trim(),
            'test_type': 'academic',
            'passage_number': nextPassageNumber,
            'difficulty': difficulty,
            'target_band': 6.5,
            'source': sourceController.text.trim(),
            'is_published': true,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      savedPassageId = inserted['id'].toString();

      await _fetchSavedQuestions();
      _msg('Passage saved');
    } catch (e) {
      _msg('Passage save failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _ensurePassageSaved() async {
    if (savedPassageId == null) {
      await _savePassage();
    }
  }

  Future<void> _generateQuestions() async {
    if (passageController.text.trim().isEmpty) {
      _msg('Enter passage first');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await GroqService.generateReadingQuestions(
        passageText: passageController.text.trim(),
      );

      setState(() {
        generatedQuestions =
            List<Map<String, dynamic>>.from(result['questions'] ?? []);
      });

      _msg('AI questions generated');
    } catch (e) {
      _msg('AI generation failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveGeneratedQuestions() async {
    await _ensurePassageSaved();

    if (savedPassageId == null) {
      _msg('Passage not saved');
      return;
    }

    if (generatedQuestions.isEmpty) {
      _msg('Generate questions first');
      return;
    }

    setState(() => isLoading = true);

    try {
      for (int i = 0; i < generatedQuestions.length; i++) {
        final q = generatedQuestions[i];
        await _insertQuestion(
          questionText: q['question_text']?.toString() ?? '',
          type: _normalType(q['question_type']?.toString() ?? ''),
          correctAnswer: q['correct_answer']?.toString() ?? '',
          explanation: q['explanation']?.toString() ?? '',
          order: savedQuestions.length + i + 1,
          options: q['options'] is List ? List<String>.from(q['options']) : [],
        );
      }

      generatedQuestions.clear();
      await _fetchSavedQuestions();
      _msg('AI questions saved');
    } catch (e) {
      _msg('Save AI questions failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addManualQuestion() async {
    await _ensurePassageSaved();

    if (savedPassageId == null) {
      _msg('Passage not saved');
      return;
    }

    if (questionController.text.trim().isEmpty ||
        answerController.text.trim().isEmpty) {
      _msg('Question and answer required');
      return;
    }

    final options = _hasOptions(questionType)
        ? [
            option1Controller.text.trim(),
            option2Controller.text.trim(),
            option3Controller.text.trim(),
            option4Controller.text.trim(),
          ].where((e) => e.isNotEmpty).toList()
        : <String>[];

    if (_hasOptions(questionType) && options.length < 2) {
      _msg('This question type needs options');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _insertQuestion(
        questionText: questionController.text.trim(),
        type: _normalType(questionType),
        correctAnswer: answerController.text.trim(),
        explanation: explanationController.text.trim(),
        order: savedQuestions.length + 1,
        options: options,
      );

      questionController.clear();
      answerController.clear();
      explanationController.clear();
      option1Controller.clear();
      option2Controller.clear();
      option3Controller.clear();
      option4Controller.clear();

      await _fetchSavedQuestions();
      _msg('Manual question added');
    } catch (e) {
      _msg('Manual question save failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _insertQuestion({
    required String questionText,
    required String type,
    required String correctAnswer,
    required String explanation,
    required int order,
    required List<String> options,
  }) async {
    if (questionText.trim().isEmpty || correctAnswer.trim().isEmpty) return;

    final inserted = await supabase
        .from('reading_questions')
        .insert({
          'passage_id': savedPassageId,
          'question_text': questionText.trim(),
          'question_type': _normalType(type),
          'question_order': order,
          'correct_answer': correctAnswer.trim(),
          'explanation': explanation.trim(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final questionId = inserted['id'].toString();

    if (_hasOptions(type)) {
      final cleanOptions = options.where((e) => e.trim().isNotEmpty).toList();

      if (cleanOptions.isNotEmpty) {
        await supabase.from('reading_options').insert(
              List.generate(cleanOptions.length, (index) {
                return {
                  'question_id': questionId,
                  'option_text': cleanOptions[index],
                  'option_order': index + 1,
                };
              }),
            );
      }
    }
  }

  Future<void> _fetchSavedPassages() async {
    final data = await supabase
        .from('reading_passages')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      savedPassages = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _openSavedPassage(Map<String, dynamic> passage) async {
    setState(() {
      savedPassageId = passage['id'].toString();
      titleController.text = passage['title']?.toString() ?? '';
      passageController.text = passage['passage_text']?.toString() ?? '';
      sourceController.text = passage['source']?.toString() ?? 'Admin / AI';
      difficulty = passage['difficulty']?.toString() ?? 'medium';
    });

    await _fetchSavedQuestions();
  }

  Future<void> _updatePassage() async {
    if (savedPassageId == null) {
      _msg('Open a saved passage first');
      return;
    }

    if (titleController.text.trim().isEmpty ||
        passageController.text.trim().isEmpty) {
      _msg('Title and passage required');
      return;
    }

    setState(() => isLoading = true);

    try {
      final updated = await supabase
          .from('reading_passages')
          .update({
            'title': titleController.text.trim(),
            'passage_text': passageController.text.trim(),
            'difficulty': difficulty,
            'source': sourceController.text.trim(),
          })
          .eq('id', savedPassageId!)
          .select();

      if (updated.isEmpty) {
        _msg('Passage update failed. Check Supabase update policy.');
        return;
      }

      await _fetchSavedPassages();
      _msg('Passage updated successfully');
    } catch (e) {
      _msg('Passage update failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSavedQuestions() async {
    if (savedPassageId == null) return;

    final data = await supabase
        .from('reading_questions')
        .select('''
        *,
        reading_options(*)
      ''')
        .eq('passage_id', savedPassageId!)
        .order('question_order', ascending: true);

    final questions = List<Map<String, dynamic>>.from(data);

    for (final q in questions) {
      final options = q['reading_options'];

      if (options is List) {
        options.sort((a, b) {
          final ao = a['option_order'] ?? 0;
          final bo = b['option_order'] ?? 0;
          return ao.compareTo(bo);
        });
      }
    }

    setState(() {
      savedQuestions = questions;
    });
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      await supabase.from('reading_options').delete().eq('question_id', id);
      await supabase.from('reading_questions').delete().eq('id', id);
      await _fetchSavedQuestions();
      _msg('Question deleted');
    } catch (e) {
      _msg('Delete failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deletePassage(String passageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Passage'),
        content: const Text(
            'This will delete the passage and all its questions. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      final questions = await supabase
          .from('reading_questions')
          .select('id')
          .eq('passage_id', passageId);

      for (final q in questions) {
        await supabase
            .from('reading_options')
            .delete()
            .eq('question_id', q['id']);
      }

      await supabase
          .from('reading_questions')
          .delete()
          .eq('passage_id', passageId);

      final remainingPassages = await supabase
          .from('reading_passages')
          .select('id')
          .order('passage_number', ascending: true);

      for (int i = 0; i < remainingPassages.length; i++) {
        await supabase.from('reading_passages').update({
          'passage_number': i + 1,
        }).eq('id', remainingPassages[i]['id']);
      }
      if (savedPassageId == passageId) {
        titleController.clear();
        passageController.clear();
        sourceController.text = 'Admin / AI';
        savedPassageId = null;
        savedQuestions.clear();
      }

      final updatedPassages = await supabase
          .from('reading_passages')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        savedPassages = List<Map<String, dynamic>>.from(updatedPassages);
      });

      _msg('Passage deleted');
    } catch (e) {
      _msg('Passage delete failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: primaryRed,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textGrey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: neutralBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryRed, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: textDark,
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _generatedPreview() {
    if (generatedQuestions.isEmpty) {
      return const Text(
        'No AI questions generated yet.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: generatedQuestions.asMap().entries.map((entry) {
        final index = entry.key;
        final q = entry.value;
        final options = q['options'];

        return Card(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: neutralBorder),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q${index + 1}. ${q['question_text'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Type: ${_normalType(q['question_type']?.toString() ?? '')}'),
                Text('Answer: ${q['correct_answer'] ?? ''}'),
                if (options is List) ...[
                  const SizedBox(height: 6),
                  const Text('Options:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...options.map((o) => Text('- $o')),
                ],
                if ((q['explanation'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Explanation: ${q['explanation']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _savedPassagesList() {
    if (savedPassages.isEmpty) {
      return const Text(
        'No saved passages yet.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: savedPassages.map((p) {
        return Card(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: neutralBorder),
          ),
          child: ListTile(
            title: Text(p['title']?.toString() ?? ''),
            subtitle: Text('Difficulty: ${p['difficulty'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: primaryRed,
                  ),
                  onPressed: () => _deletePassage(
                    p['id'].toString(),
                  ),
                ),
                const Icon(Icons.open_in_new),
              ],
            ),
            onTap: () => _openSavedPassage(p),
          ),
        );
      }).toList(),
    );
  }

  void _showEditQuestionDialog(Map<String, dynamic> q) {
    final editQuestionController = TextEditingController(
      text: q['question_text']?.toString() ?? '',
    );
    final editAnswerController = TextEditingController(
      text: q['correct_answer']?.toString() ?? '',
    );
    final editExplanationController = TextEditingController(
      text: q['explanation']?.toString() ?? '',
    );

    String editQuestionType = q['question_type']?.toString() ?? 'MCQ';

    final options = q['reading_options'] is List
        ? List<Map<String, dynamic>>.from(q['reading_options'])
        : <Map<String, dynamic>>[];

    final editOption1Controller = TextEditingController(
      text:
          options.isNotEmpty ? options[0]['option_text']?.toString() ?? '' : '',
    );
    final editOption2Controller = TextEditingController(
      text:
          options.length > 1 ? options[1]['option_text']?.toString() ?? '' : '',
    );
    final editOption3Controller = TextEditingController(
      text:
          options.length > 2 ? options[2]['option_text']?.toString() ?? '' : '',
    );
    final editOption4Controller = TextEditingController(
      text:
          options.length > 3 ? options[3]['option_text']?.toString() ?? '' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final showEditOptions = _hasOptions(editQuestionType);

            return AlertDialog(
              title: const Text('Edit Question'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(editQuestionController, 'Question Text',
                        maxLines: 3),
                    DropdownButtonFormField<String>(
                      value: editQuestionType,
                      decoration: const InputDecoration(
                        labelText: 'Question Type',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items: questionTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            editQuestionType = v;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (editQuestionType == 'true_false_not_given')
                      DropdownButtonFormField<String>(
                        value: editAnswerController.text.isEmpty
                            ? null
                            : editAnswerController.text,
                        decoration: const InputDecoration(
                          labelText: 'Correct Answer',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'True', child: Text('True')),
                          DropdownMenuItem(
                              value: 'False', child: Text('False')),
                          DropdownMenuItem(
                            value: 'Not Given',
                            child: Text('Not Given'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            editAnswerController.text = v;
                          }
                        },
                      )
                    else
                      _field(editAnswerController, 'Correct Answer'),
                    const SizedBox(height: 12),
                    _field(editExplanationController, 'Explanation',
                        maxLines: 2),
                    if (showEditOptions) ...[
                      _field(editOption1Controller, 'Option 1'),
                      _field(editOption2Controller, 'Option 2'),
                      _field(editOption3Controller, 'Option 3'),
                      _field(editOption4Controller, 'Option 4'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final cleanOptions = showEditOptions
                          ? [
                              editOption1Controller.text.trim(),
                              editOption2Controller.text.trim(),
                              editOption3Controller.text.trim(),
                              editOption4Controller.text.trim(),
                            ].where((e) => e.isNotEmpty).toList()
                          : <String>[];

                      if (editQuestionController.text.trim().isEmpty ||
                          editAnswerController.text.trim().isEmpty) {
                        _msg('Question and answer required');
                        return;
                      }

                      if (showEditOptions && cleanOptions.length < 2) {
                        _msg('This question type needs at least 2 options');
                        return;
                      }

                      final updated = await supabase
                          .from('reading_questions')
                          .update({
                            'question_text': editQuestionController.text.trim(),
                            'question_type': _normalType(editQuestionType),
                            'correct_answer': editAnswerController.text.trim(),
                            'explanation':
                                editExplanationController.text.trim(),
                          })
                          .eq('id', q['id'])
                          .select();

                      if (updated.isEmpty) {
                        _msg('Question update failed. Check update policy.');
                        return;
                      }

                      await supabase
                          .from('reading_options')
                          .delete()
                          .eq('question_id', q['id']);

                      if (showEditOptions && cleanOptions.isNotEmpty) {
                        await supabase.from('reading_options').insert(
                              List.generate(cleanOptions.length, (index) {
                                return {
                                  'question_id': q['id'],
                                  'option_text': cleanOptions[index],
                                  'option_order': index + 1,
                                };
                              }),
                            );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);

                      await _fetchSavedQuestions();
                      _msg('Question updated successfully');
                    } catch (e) {
                      _msg('Question update failed: $e');
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _savedList() {
    if (savedQuestions.isEmpty) {
      return const Text(
        'No saved questions yet.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: savedQuestions.map((q) {
        return Card(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: neutralBorder),
          ),
          child: ListTile(
            title: Text(q['question_text']?.toString() ?? ''),
            subtitle: Text(
              'Type: ${q['question_type']} | Answer: ${q['correct_answer']}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                  onPressed: () => _showEditQuestionDialog(q),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: primaryRed,
                  ),
                  onPressed: () => _deleteQuestion(
                    q['id'].toString(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _clearAll() {
    titleController.clear();
    passageController.clear();
    sourceController.text = 'Admin / AI';

    questionController.clear();
    answerController.clear();
    explanationController.clear();

    option1Controller.clear();
    option2Controller.clear();
    option3Controller.clear();
    option4Controller.clear();

    savedPassageId = null;

    generatedQuestions.clear();
    savedQuestions.clear();

    difficulty = 'medium';
    questionType = 'MCQ';

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showOptions = _hasOptions(questionType);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(
          'Admin Reading Page',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Form',
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _clearAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Saved Passages'),
                _savedPassagesList(),
                _title('1. Passage'),
                _field(titleController, 'Passage Title'),
                _field(passageController, 'Passage Text', maxLines: 9),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: InputDecoration(
                    labelText: 'Difficulty',
                    labelStyle: const TextStyle(color: textGrey),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: neutralBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: primaryRed, width: 1.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => difficulty = v);
                  },
                ),
                const SizedBox(height: 12),
                _field(sourceController, 'Source'),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : savedPassageId == null
                            ? _savePassage
                            : _updatePassage,
                    icon: Icon(
                        savedPassageId == null ? Icons.save : Icons.update),
                    label: Text(savedPassageId == null
                        ? 'Save Passage'
                        : 'Update Passage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                _title('2. Generate Questions with AI'),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _generateQuestions,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _saveGeneratedQuestions,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Save AI Qs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _generatedPreview(),
                _title('3. Add Question Manually'),
                _field(questionController, 'Question Text', maxLines: 3),
                DropdownButtonFormField<String>(
                  value: questionType,
                  decoration: InputDecoration(
                    labelText: 'Question Type',
                    labelStyle: const TextStyle(color: textGrey),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: neutralBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: primaryRed, width: 1.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: questionTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => questionType = v);
                  },
                ),
                const SizedBox(height: 12),
                if (questionType == 'true_false_not_given')
                  DropdownButtonFormField<String>(
                    value: answerController.text.isEmpty
                        ? null
                        : answerController.text,
                    decoration: InputDecoration(
                      labelText: 'Correct Answer',
                      labelStyle: const TextStyle(color: textGrey),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: neutralBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: primaryRed, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'True', child: Text('True')),
                      DropdownMenuItem(value: 'False', child: Text('False')),
                      DropdownMenuItem(
                        value: 'Not Given',
                        child: Text('Not Given'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) answerController.text = v;
                    },
                  )
                else
                  _field(answerController, 'Correct Answer'),
                const SizedBox(height: 12),
                _field(explanationController, 'Explanation', maxLines: 2),
                if (showOptions) ...[
                  _field(option1Controller, 'Option 1'),
                  _field(option2Controller, 'Option 2'),
                  _field(option3Controller, 'Option 3'),
                  _field(option4Controller, 'Option 4'),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _addManualQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Manual Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                _title('4. Saved Questions'),
                _savedList(),
                const SizedBox(height: 60),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: const Color(0x14F44336),
              child: const Center(
                child: CircularProgressIndicator(
                  color: primaryRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
