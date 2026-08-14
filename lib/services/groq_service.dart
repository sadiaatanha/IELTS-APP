import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class GroqService {
  static const String _model = 'llama-3.3-70b-versatile';

  static Uri get _url => Uri.parse(
        'https://api.groq.com/openai/v1/chat/completions',
      );

  static Future<String> _sendPrompt(String prompt) async {
    final response = await http.post(
      _url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1,
        'max_tokens': 1800,
        'response_format': {'type': 'json_object'},
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.body}');
    }

    final text = data['choices']?[0]?['message']?['content'];

    if (text == null || text.toString().trim().isEmpty) {
      throw Exception('Groq returned empty response: ${response.body}');
    }

    return text.toString().trim();
  }

  static Future<String> testConnection() async {
    final response = await http.post(
      _url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': 'Reply with only: Groq Connected Successfully'
          }
        ],
        'temperature': 0.2,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return data['choices'][0]['message']['content'];
  }

 static Future<Map<String, dynamic>> checkWriting({
  required String module,
  required String question,
  required String answer,
  String imageUrl = '',
  String chartType = '',
}) async {
  final wordCount = answer.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  final prompt = '''
You are a strict certified IELTS Writing examiner.

Evaluate this IELTS Writing answer using official IELTS band descriptors.

Module: $module
Chart Type: $chartType
Image URL: $imageUrl
Word Count: $wordCount

Question:
$question

Student Answer:
$answer

Important rules:
- Do NOT be generous.
- Do NOT give a fixed/default score.
- Do NOT assume the answer is good.
- Penalize if the answer is too short.
- Penalize memorized or generic answers.
- Judge only based on IELTS criteria.
- Give separate scores for each criterion.
- Overall band must be the average of the criteria rounded to nearest 0.5.

For Task 1 criteria:
1. Task Achievement
2. Coherence and Cohesion
3. Lexical Resource
4. Grammatical Range and Accuracy

For Task 2 criteria:
1. Task Response
2. Coherence and Cohesion
3. Lexical Resource
4. Grammatical Range and Accuracy

Return ONLY valid JSON.
Do not use markdown.
Do not wrap JSON in ```json.
Do not add explanation outside JSON.

Use exactly this JSON structure:

{
  "task_score": 0,
  "coherence_score": 0,
  "vocabulary_score": 0,
  "grammar_score": 0,
  "band_score": 0,
  "overall_feedback": "Write 4-6 detailed sentences explaining the overall writing quality.",
  "grammar_feedback": "Write 4-6 detailed sentences. Mention grammar mistakes, sentence structure, tense, articles, punctuation, and complex sentence accuracy.",
  "vocabulary_feedback": "Write 4-6 detailed sentences. Mention word choice, repetition, collocation, spelling, and academic vocabulary.",
  "coherence_feedback": "Write 4-6 detailed sentences. Mention paragraphing, linking words, logical flow, progression, and clarity.",
  "strengths": ["", "", ""],
  "weaknesses": ["", "", ""],
  "sentence_corrections": [
    {
      "original": "",
      "improved": "",
      "reason": ""
    }
  ],
  "improvement_tips": ["", "", "", ""]
}
''';

  final cleanText = await _sendPrompt(prompt);

  try {
    final decoded = jsonDecode(
      cleanText.replaceAll('```json', '').replaceAll('```', '').trim(),
    );

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double roundToHalf(double value) {
      return (value * 2).round() / 2;
    }

    final taskScore = toDouble(decoded['task_score']);
    final coherenceScore = toDouble(decoded['coherence_score']);
    final vocabularyScore = toDouble(decoded['vocabulary_score']);
    final grammarScore = toDouble(decoded['grammar_score']);

    final calculatedBand = roundToHalf(
      (taskScore + coherenceScore + vocabularyScore + grammarScore) / 4,
    );

    return {
      'band_score': calculatedBand.toStringAsFixed(1),
      'overall_feedback':
          decoded['overall_feedback']?.toString() ?? 'No overall feedback.',
      'grammar_feedback':
          decoded['grammar_feedback']?.toString() ?? 'No grammar feedback.',
      'vocabulary_feedback':
          decoded['vocabulary_feedback']?.toString() ?? 'No vocabulary feedback.',
      'coherence_feedback':
          decoded['coherence_feedback']?.toString() ?? 'No coherence feedback.',
      'improvement_tips': decoded['improvement_tips'] is List
          ? decoded['improvement_tips']
          : <String>[],
      'strengths': decoded['strengths'] is List ? decoded['strengths'] : <String>[],
      'weaknesses': decoded['weaknesses'] is List ? decoded['weaknesses'] : <String>[],
      'sentence_corrections': decoded['sentence_corrections'] is List
    ? decoded['sentence_corrections']
    : <dynamic>[],
    };
  } catch (e) {
    throw Exception('Failed to parse Groq writing JSON: $cleanText');
  }
}

  static Future<Map<String, dynamic>> checkSpeaking({
    required String part,
    required String topic,
    required String cuePoints,
    required String transcript,
  }) async {
    final prompt = '''
You are an IELTS Speaking examiner.

Speaking Part: $part

Topic:
$topic

Cue Points:
$cuePoints

Candidate Transcript:
$transcript

Evaluate the speaking answer and return ONLY valid JSON.
Do not use markdown.
Do not wrap JSON in ```json.
Do not add explanation outside JSON.

Evaluate the speaking answer using IELTS Speaking band descriptors.

Score based on:
- Fluency and Coherence
- Lexical Resource
- Grammatical Range and Accuracy
- Pronunciation

Rules:
- Do not give the same band for every answer.
- Very short answers should receive a low score.
- Off-topic answers should receive a low score.
- Average answers should receive around Band 5.0–6.0.
- Good detailed answers should receive around Band 6.5–8.0.
- Calculate the overall band_score from the four criteria.
- band_score must be between 0 and 9 and may include .5 increments.
- Return band_score as a string, for example "5.5", "6.0", or "7.0".

Return ONLY valid JSON.

{
  "band_score": "0.0",
  "fluency": "",
  "vocabulary": "",
  "grammar": "",
  "pronunciation": "",
  "overall_feedback": "",
  "improvement_tips": []
}
''';

    final cleanText = await _sendPrompt(prompt);

    try {
      final decoded = jsonDecode(
        cleanText.replaceAll('```json', '').replaceAll('```', '').trim(),
      );

      return {
        'band_score': decoded['band_score']?.toString() ?? '0.0',
        'fluency': decoded['fluency']?.toString() ?? 'No fluency feedback.',
        'vocabulary':
            decoded['vocabulary']?.toString() ?? 'No vocabulary feedback.',
        'grammar': decoded['grammar']?.toString() ?? 'No grammar feedback.',
        'pronunciation': decoded['pronunciation']?.toString() ??
            'No pronunciation feedback.',
        'overall_feedback':
            decoded['overall_feedback']?.toString() ?? 'No overall feedback.',
        'improvement_tips': decoded['improvement_tips'] is List
            ? decoded['improvement_tips']
            : <String>[],
      };
    } catch (e) {
      throw Exception('Failed to parse Groq speaking JSON: $cleanText');
    }
  }

  static Future<Map<String, dynamic>> generateReadingQuestions({
    required String passageText,
  }) async {
    final prompt = '''
You are an IELTS Academic Reading question creator.

Create 13 IELTS Academic Reading questions from the passage below.

Return ONLY valid JSON.
Do not use markdown.
Do not wrap the JSON in ```json.
Do not add explanation outside JSON.

Use exactly this JSON structure:

{
  "questions": [
    {
      "question_text": "",
      "question_type": "MCQ",
      "correct_answer": "",
      "explanation": "",
      "options": ["", "", "", ""]
    }
  ]
}

Rules:
- Use mixed types: MCQ, fill_blank, true_false_not_given, matching_heading, matching_information, short_answer.
- For MCQ, matching_heading, and matching_information, include options array.
- For MCQ, correct_answer must exactly match one option text.
- For matching_heading, correct_answer must exactly match one heading option.
- For matching_information, correct_answer must exactly match one paragraph option.
- For true_false_not_given, correct_answer must be only: True, False, or Not Given.
- For fill_blank and short_answer, use one short answer only.
- Questions must be based only on the passage.

Passage:
$passageText
''';

    final cleanText = await _sendPrompt(prompt);

    try {
      final decoded = jsonDecode(
        cleanText.replaceAll('```json', '').replaceAll('```', '').trim(),
      );

      return {
        'questions': decoded['questions'] is List ? decoded['questions'] : [],
      };
    } catch (e) {
      throw Exception('Failed to parse Groq reading JSON: $cleanText');
    }
  }
}
