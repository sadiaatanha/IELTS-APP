import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminListeningPage extends StatefulWidget {
  const AdminListeningPage({super.key});

  @override
  State<AdminListeningPage> createState() => _AdminListeningPageState();
}
final marksController = TextEditingController();
class _AdminListeningPageState extends State<AdminListeningPage> {
  final supabase = Supabase.instance.client;

  final testTitle = TextEditingController();
  final sectionTitle = TextEditingController();
  final audioUrl = TextEditingController();
  final instructions = TextEditingController();

  final questionNo = TextEditingController();
  final questionText = TextEditingController();
  final contextText = TextEditingController();
  final optionsText = TextEditingController();
  final answerText = TextEditingController();
  final imageUrl = TextEditingController();

  String? selectedTestId;
  String? selectedSectionId;
  String? editingQuestionId;

  String selectedPart = 'part1';
  String selectedType = 'completion';

  List<Map<String, dynamic>> tests = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    loadTests();
  }

  @override
  void dispose() {
    testTitle.dispose();
    sectionTitle.dispose();
    audioUrl.dispose();
    instructions.dispose();
    questionNo.dispose();
    questionText.dispose();
    contextText.dispose();
    optionsText.dispose();
    answerText.dispose();
    imageUrl.dispose();
    super.dispose();
  }

  Future<void> loadTests() async {
    final data = await supabase
        .from('listening_tests')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      tests = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> loadSections() async {
    if (selectedTestId == null) return;

    final data = await supabase
        .from('listening_sections')
        .select()
        .eq('test_id', selectedTestId!)
        .order('section_no');

    setState(() {
      sections = List<Map<String, dynamic>>.from(data);
      selectedSectionId = null;
      questions = [];
      editingQuestionId = null;
    });
  }

  Future<void> loadQuestions() async {
    if (selectedSectionId == null) return;

    final data = await supabase
        .from('listening_questions')
        .select()
        .eq('section_id', selectedSectionId!)
        .order('question_no');

    setState(() {
      questions = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> createTest() async {
    if (testTitle.text.trim().isEmpty) {
      showMsg('Enter test title');
      return;
    }

    try {
      await supabase.from('listening_tests').insert({
        'title': testTitle.text.trim(),
        'level': 'IELTS',
        'description': 'IELTS Listening Practice',
        'is_published': true,
      });

      testTitle.clear();
      await loadTests();
      showMsg('Test created');
    } catch (e) {
      showMsg('Create test failed: $e');
    }
  }

  Future<void> createSection() async {
    if (selectedTestId == null) {
      showMsg('Select test first');
      return;
    }

    if (sectionTitle.text.trim().isEmpty || audioUrl.text.trim().isEmpty) {
      showMsg('Section title and audio URL required');
      return;
    }

    int sectionNo = 1;
    if (selectedPart == 'part2') sectionNo = 2;
    if (selectedPart == 'part3') sectionNo = 3;
    if (selectedPart == 'part4') sectionNo = 4;

    try {
      await supabase.from('listening_sections').insert({
        'test_id': selectedTestId,
        'section_no': sectionNo,
        'section_type': selectedPart,
        'title': sectionTitle.text.trim(),
        'instructions': instructions.text.trim(),
        'audio_url': audioUrl.text.trim(),
        'transcript': '',
      });

      sectionTitle.clear();
      audioUrl.clear();
      instructions.clear();

      await loadSections();
      showMsg('Section added');
    } catch (e) {
      showMsg('Section add failed: $e');
    }
  }
  Future<void> deleteSection(String id) async {
  try {
    await supabase.from('listening_sections').delete().eq('id', id);

    setState(() {
      if (selectedSectionId == id) {
        selectedSectionId = null;
        questions = [];
      }
    });

    await loadSections();
    showMsg('Section deleted');
  } catch (e) {
    showMsg('Section delete failed: $e');
  }
}

  dynamic formatOptions() {
    final text = optionsText.text.trim();

    if (text.isEmpty) return null;

    if (selectedType == 'mcq' || selectedType == 'multi_mcq') {
  return optionsText.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

    if (selectedType == 'matching') {
      return jsonDecode(text);
    }

    if (selectedType == 'map') {
      return {
        'labels': text.split(',').map((e) => e.trim()).toList(),
      };
    }

    return null;
  }

  dynamic formatAnswer() {
    final text = answerText.text.trim();

    if (selectedType == 'multi_mcq') {
      return text.split(',').map((e) => e.trim()).toList();
    }

    if (selectedType == 'matching') {
      return jsonDecode(text);
    }

    return text;
  }

  Future<void> addQuestion() async {
    if (selectedSectionId == null) {
      showMsg('Select section first');
      return;
      
    }

    if (questionNo.text.trim().isEmpty ||
        questionText.text.trim().isEmpty ||
        answerText.text.trim().isEmpty) {
      showMsg('Question no, question text, and answer required');
      return;
    }

    try {
      await supabase.from('listening_questions').insert({
        'section_id': selectedSectionId,
        'question_no': questionNo.text.trim(),
        'question_text': questionText.text.trim(),
        'context_text':
            contextText.text.trim().isEmpty ? null : contextText.text.trim(),
        'question_type': selectedType,
        'options': formatOptions(),
        'correct_answer': formatAnswer(),
        'image_url': imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
        'marks': int.tryParse(marksController.text.trim()) ?? 1,
      });

      clearQuestionFields();
      await loadQuestions();
      showMsg('Question added');
    } catch (e) {
      showMsg('Question add failed: $e');
    }
  }

  void startEditQuestion(Map<String, dynamic> q) {
    setState(() {
      editingQuestionId = q['id'];

      questionNo.text = q['question_no'].toString();
      questionText.text = q['question_text'] ?? '';
      contextText.text = q['context_text'] ?? '';
      selectedType = q['question_type'];

      optionsText.text = q['options'] == null
          ? ''
          : q['options'] is String
              ? q['options']
              : jsonEncode(q['options']);

      answerText.text = q['correct_answer'] == null
          ? ''
          : q['correct_answer'] is String
              ? q['correct_answer']
              : jsonEncode(q['correct_answer']);

      imageUrl.text = q['image_url'] ?? '';
    });
  }

  Future<void> updateQuestion() async {
    if (editingQuestionId == null) return;

    if (questionNo.text.trim().isEmpty ||
        questionText.text.trim().isEmpty ||
        answerText.text.trim().isEmpty) {
      showMsg('Question no, question text, and answer required');
      return;
    }

    try {
      await supabase.from('listening_questions').update({
        'question_no': questionNo.text.trim(),
        'question_text': questionText.text.trim(),
        'context_text':
            contextText.text.trim().isEmpty ? null : contextText.text.trim(),
        'question_type': selectedType,
        'options': formatOptions(),
        'correct_answer': formatAnswer(),
        'image_url': imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
        'marks': int.tryParse(marksController.text.trim()) ?? 1,
      }).eq('id', editingQuestionId!);

      clearQuestionFields();

      setState(() {
        editingQuestionId = null;
      });

      await loadQuestions();
      showMsg('Question updated');
    } catch (e) {
      showMsg('Question update failed: $e');
    }
  }

  Future<void> deleteQuestion(String id) async {
    await supabase.from('listening_questions').delete().eq('id', id);
    await loadQuestions();
    showMsg('Question deleted');
  }

  void clearQuestionFields() {
    questionNo.clear();
    questionText.clear();
    contextText.clear();
    optionsText.clear();
    answerText.clear();
    imageUrl.clear();
    marksController.clear();
  }

  void cancelEdit() {
    clearQuestionFields();

    setState(() {
      editingQuestionId = null;
    });
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String optionHint() {
    if (selectedType == 'mcq' || selectedType == 'multi_mcq') {
      return 'A. Library\nB. Museum\nC. Park';
    }

    if (selectedType == 'matching') {
      return '{"items":["Asia","Europe"],"choices":["A","B","C","D"]}';
    }

    if (selectedType == 'map') {
      return 'A,B,C,D,E,F';
    }

    return 'Leave empty';
  }

  String answerHint() {
    if (selectedType == 'multi_mcq') return 'B,C';
    if (selectedType == 'matching') return '{"Asia":"E","Europe":"A"}';
    if (selectedType == 'mcq') return 'B';
    if (selectedType == 'map') return 'C';
    return 'Hardie';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F9),
      appBar: AppBar(
        title: const Text('Admin Listening'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
     body: SingleChildScrollView(
  padding: const EdgeInsets.all(18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
            title('1. Create Listening Test'),
            input(testTitle, 'Test title'),
            button('Create Test', createTest),

            title('2. Select Test'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedTestId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: tests.map((test) {
                return DropdownMenuItem<String>(
                  value: test['id'],
                  child: Text(
  test['title'],
  overflow: TextOverflow.ellipsis,
  maxLines: 1,
),
                );
              }).toList(),
              onChanged: (value) async {
                setState(() => selectedTestId = value);
                await loadSections();
              },
            ),

            title('3. Add Listening Part'),
            DropdownButtonFormField<String>(
            isExpanded: true,
              value: selectedPart,
              decoration: const InputDecoration(
                labelText: 'Part',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'part1', child: Text('Part 1')),
                DropdownMenuItem(value: 'part2', child: Text('Part 2')),
                DropdownMenuItem(value: 'part3', child: Text('Part 3')),
                DropdownMenuItem(value: 'part4', child: Text('Part 4')),
              ],
              onChanged: (v) => setState(() => selectedPart = v!),
            ),
            const SizedBox(height: 10),
            input(sectionTitle, 'Section title'),
            input(instructions, 'Instructions'),
            input(audioUrl, 'Audio public URL'),
            button('Add Section', createSection),

const SizedBox(height: 12),

if (sections.isNotEmpty) ...[
  const Text(
    'Saved Sections',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 8),

  ...sections.map((section) {
    return Card(
      child: ListTile(
        title: Text(
          '${section['section_type']} - ${section['title']}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => deleteSection(section['id']),
        ),
      ),
    );
  }),
],

            title('4. Select Section'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedSectionId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: sections.map((section) {
                return DropdownMenuItem<String>(
                  value: section['id'],
                  child: Text(
                    '${section['section_type']} - ${section['title']}',
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                setState(() {
                  selectedSectionId = value;
                  editingQuestionId = null;
                });
                clearQuestionFields();
                await loadQuestions();
              },
            ),

            title('5. Question Manager'),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                editingQuestionId == null ? 'Add Question' : 'Update Question',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            input(questionNo, 'Question no'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Question type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'completion', child: Text('Completion')),
                DropdownMenuItem(
                    value: 'short_answer', child: Text('Short Answer')),
                DropdownMenuItem(value: 'mcq', child: Text('MCQ')),
                DropdownMenuItem(value: 'multi_mcq', child: Text('Multi MCQ')),
                DropdownMenuItem(value: 'matching', child: Text('Matching')),
                DropdownMenuItem(value: 'map', child: Text('Map')),
              ],
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 10),
            input(
              contextText,
              'Optional context / extra information',
              maxLines: 4,
            ),
            input(questionText, 'Question text', maxLines: 3),
            input(marksController, 'Marks for this question'),
            input(optionsText, 'Options: ${optionHint()}', maxLines: 5),
            input(answerText, 'Correct answer: ${answerHint()}', maxLines: 3),

            if (selectedType == 'map') input(imageUrl, 'Map image URL'),

            button(
              editingQuestionId == null ? 'Save Question' : 'Update Question',
              editingQuestionId == null ? addQuestion : updateQuestion,
            ),

            if (editingQuestionId != null) ...[
              const SizedBox(height: 8),
              button('Cancel Edit', cancelEdit),
            ],

            title('Saved Questions'),

            if (selectedSectionId == null)
              const Text('Select a section to see saved questions'),

            if (selectedSectionId != null && questions.isEmpty)
              const Text('No questions added yet'),

            ...questions.map((q) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
  'Q${q['question_no']}. ${q['question_text']}',
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${q['question_type']}'),
                      if (q['context_text'] != null &&
                          q['context_text'].toString().trim().isNotEmpty)
                        Text('Context: ${q['context_text']}'),
                      Text('Answer: ${q['correct_answer']}'),
                    ],
                  ),
                  trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.edit, color: Colors.blue),
      onPressed: () => startEditQuestion(q),
    ),
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => deleteQuestion(q['id']),
    ),
  ],
),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget input(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget button(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: Text(text),
      ),
    );
  }
}