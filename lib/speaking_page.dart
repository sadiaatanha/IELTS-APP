import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'services/groq_service.dart';

class SpeakingPage extends StatefulWidget {
  const SpeakingPage({super.key});

  @override
  State<SpeakingPage> createState() => _SpeakingPageState();
}

class _SpeakingPageState extends State<SpeakingPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final supabase = Supabase.instance.client;

  Timer? _timer;

  bool _isLoadingTopics = true;
  bool _isPreparing = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _hasResult = false;

  bool _isCustomTopic = false;

  int _prepSeconds = 60;
  int _speakSeconds = 300;

  String _selectedPart = "Part 1";
  String _topic = "";
  String _cuePoints = "";
  String _transcript = "";

  final customTopicController = TextEditingController();
  final customCueController = TextEditingController();

  double _bandScore = 0.0;
  String _fluency = "";
  String _vocabulary = "";
  String _grammar = "";
  String _pronunciation = "";
  String _overallFeedback = "";

  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _history = [];

  int _getSpeakingSeconds() {
    if (_selectedPart == "Part 2") return 120;
    return 300;
  }

  ButtonStyle _ashButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE5E7EB),
      foregroundColor: const Color(0xFFE60046),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _speakSeconds = _getSpeakingSeconds();
    _fetchTopics();
    _fetchHistory();
  }

  
  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();

    customTopicController.dispose();
    customCueController.dispose();

    super.dispose();
  }

  Future<void> _fetchTopics() async {
    setState(() => _isLoadingTopics = true);

    try {
      final data = await supabase
          .from('speaking_topics')
          .select()
          .eq('part', _selectedPart)
          .order('created_at', ascending: false);

      _topics = List<Map<String, dynamic>>.from(data);

      _generateTopic();
    } catch (e) {
      _showMessage("Failed to load speaking topics: $e");
      _topic = "No topic found. Please ask admin to add speaking topics.";
      _cuePoints = "";
    }

    if (mounted) {
      setState(() => _isLoadingTopics = false);
    }
  }

  void _generateTopic() {
    if (_topics.isEmpty) {
      _topic = "No topic found. Please ask admin to add speaking topics.";
      _cuePoints = "";
      return;
    }

    final selected = _topics[Random().nextInt(_topics.length)];

    _topic = selected['topic']?.toString() ?? '';
    _cuePoints = selected['cue_points']?.toString() ?? '';
    _isCustomTopic = false;
  }

  void _useCustomTopic() {
  final topic = customTopicController.text.trim();
  final cue = customCueController.text.trim();

  if (topic.isEmpty) {
    _showMessage("Enter your custom topic");
    return;
  }

  setState(() {
    _resetAll();
    _topic = topic;
    _cuePoints = _selectedPart == "Part 2" ? cue : "";
    _isCustomTopic = true;
  });

  customTopicController.clear();
  customCueController.clear();

  _showMessage("Custom topic added temporarily. Result will not be saved.");
}

  void _changePart(String part) {
    if (_isRecording || _isPreparing) return;

    setState(() {
      _selectedPart = part;
      _resetAll();
    });

    _fetchTopics();
  }

  void _resetAll() {
    _timer?.cancel();
    _isPreparing = false;
    _isRecording = false;
    _isAnalyzing = false;
    _hasResult = false;
    _prepSeconds = 60;
    _speakSeconds = _getSpeakingSeconds();
    _transcript = "";
    _bandScore = 0.0;
    _fluency = "";
    _vocabulary = "";
    _grammar = "";
    _pronunciation = "";
    _overallFeedback = "";
  }

  Future<void> _startPreparation() async {
    if (_topic.startsWith("No topic found")) {
      _showMessage("No topic available for $_selectedPart");
      return;
    }

    setState(() {
      _resetAll();
    });

    if (_selectedPart != "Part 2") {
      await _startRecording();
      return;
    }

    setState(() {
      _isPreparing = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepSeconds <= 0) {
        timer.cancel();
        _startRecording();
      } else {
        setState(() {
          _prepSeconds--;
        });
      }
    });
  }

  Future<void> _skipPreparation() async {
    _timer?.cancel();
    setState(() {
      _isPreparing = false;
    });
    await _startRecording();
  }

  Future<void> _startRecording() async {
    final permission = await Permission.microphone.request();

    if (!permission.isGranted) {
      _showMessage("Microphone permission required");
      return;
    }

    final available = await _speech.initialize();

    if (!available) {
      _showMessage("Speech recognition not available");
      return;
    }

    setState(() {
      _isPreparing = false;
      _isRecording = true;
      _transcript = "";
      _hasResult = false;
      _speakSeconds = _getSpeakingSeconds();
    });

    _speech.listen(
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        setState(() {
          _transcript = result.recognizedWords;
        });
      },
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_speakSeconds <= 0) {
        timer.cancel();
        _stopRecording();
      } else {
        setState(() {
          _speakSeconds--;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _speech.stop();

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    await _analyzeSpeakingWithAI();
  }

  Future<void> _analyzeSpeakingWithAI() async {
    if (_transcript.trim().isEmpty) {
      setState(() {
        _bandScore = 0.0;
        _fluency = "No speech detected.";
        _vocabulary = "No vocabulary detected.";
        _grammar = "No sentence detected.";
        _pronunciation = "Pronunciation could not be analyzed.";
        _overallFeedback = "Please try again and speak clearly.";
        _isAnalyzing = false;
        _hasResult = true;
      });
      return;
    }

    try {
      final result = await GroqService.checkSpeaking(
        part: _selectedPart,
        topic: _topic,
        cuePoints: _cuePoints,
        transcript: _transcript,
      );

      setState(() {
        _bandScore = double.tryParse(result['band_score'].toString()) ?? 0.0;
        _fluency = result['fluency']?.toString() ?? '';
        _vocabulary = result['vocabulary']?.toString() ?? '';
        _grammar = result['grammar']?.toString() ?? '';
        _pronunciation = result['pronunciation']?.toString() ?? '';
        _overallFeedback = result['overall_feedback']?.toString() ?? '';
        _isAnalyzing = false;
        _hasResult = true;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _hasResult = false;
      });

      _showMessage("AI speaking feedback failed: $e");
    }
  }

  Future<void> _saveResult() async {
    if (_transcript.trim().isEmpty) {
      _showMessage("No transcript to save");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      await supabase.from('speaking_results').insert({
        'user_id': user?.id,
        'part': _selectedPart,
        'topic': _topic,
        'transcript': _transcript,
        'score': _bandScore,
        'fluency': _fluency,
        'vocabulary': _vocabulary,
        'grammar': _grammar,
        'pronunciation': _pronunciation,
        'feedback': _overallFeedback,
      });
      await supabase.from('ielts_scores').insert({
        'user_id': user?.id,
        'module': 'speaking',
        'band_score': _bandScore,
      });

      await supabase.from('homepage_scores').insert({
        'user_id': user?.id,
        'module': 'speaking',
        'band_score': _bandScore,
        'test_type': 'part_test',
        'part': _selectedPart,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showMessage("Speaking result saved");
      await _fetchHistory();
    } catch (e) {
      _showMessage("Save failed: $e");
    }

    setState(() {
      _isSaving = false;
    });
  }

  Future<void> _fetchHistory() async {
    try {
      final user = supabase.auth.currentUser;

      final response = await supabase
          .from('speaking_results')
          .select()
          .eq('user_id', user?.id ?? '')
          .order('created_at', ascending: false)
          .limit(3);

      setState(() {
        _history = List<Map<String, dynamic>>.from(response);
      });
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }

  void _goToPage(int index) {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnalyticsPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE60046), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE60046),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _partButton(String part) {
    final selected = _selectedPart == part;

    return GestureDetector(
      onTap: () => _changePart(part),
      child: Container(
        width: 92,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE60046) : const Color(0xFFFFEEF3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          part,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFE60046),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _feedbackLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: "$title: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _cuePointBox() {
    if (_selectedPart != "Part 2" || _cuePoints.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCCD8)),
      ),
      child: Text(
        "You should say:\n$_cuePoints",
        style: const TextStyle(
          color: Color(0xFFB42350),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerText =
        _isPreparing ? _formatTime(_prepSeconds) : _formatTime(_speakSeconds);

    return Scaffold(
      appBar: AppBar(
       title: const Text("Speaking"),
       backgroundColor: Colors.red,
       foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFF8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFCCD8)),
                ),
                child: const Text(
                  "Part 1: 5 minutes. Part 2: 1 minute preparation + 2 minutes speaking. Part 3: 5 minutes discussion.",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFE60046),
                    height: 1.5,
                  ),
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.category_outlined, "Speaking Part"),
                    const SizedBox(height: 14),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _partButton("Part 1"),
                          _partButton("Part 2"),
                          _partButton("Part 3"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.topic_outlined, "Your Topic"),
                    const SizedBox(height: 14),
                    _isLoadingTopics
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE60046),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _topic,
                                style: const TextStyle(
                                  fontSize: 19,
                                  color: Color(0xFF111827),
                                  height: 1.4,
                                ),
                              ),
                              _cuePointBox(),
                            ],
                          ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed:
                          _isRecording || _isPreparing || _isLoadingTopics
                              ? null
                              : () {
                                  setState(() {
                                    _resetAll();
                                    _generateTopic();
                                  });
                                },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Change Topic"),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE60046),
                      ),
                    ),
                  ],
                ),
              ),

              _card(
                child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                  _sectionTitle(Icons.add_circle_outline, "Add Your Own Topic"),
                  const SizedBox(height: 12),

                  TextField(
                   controller: customTopicController,
                   decoration: InputDecoration(
                    hintText: "Enter your custom topic",
                    filled: true,
                    fillColor: const Color(0xFFFFF8FA),
                    border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(14),
                     borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_selectedPart == "Part 2") ...[
                 const SizedBox(height: 12),
                 TextField(
                  controller: customCueController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Enter cue points for Part 2",
                    filled: true,
                    fillColor: const Color(0xFFFFF8FA),
                    border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(14),
                     borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              SizedBox(
                 width: double.infinity,
                 height: 48,
                 child: ElevatedButton.icon(
                    onPressed: _isRecording || _isPreparing ? null : _useCustomTopic,
                    icon: const Icon(Icons.check, color: Color(0xFFE60046)),
                    label: const Text(
                       "Use This Topic Temporarily",
                        style: TextStyle(
                        color: Color(0xFFE60046),
                        fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: _ashButtonStyle(),
                      ),
                    ),
                  ],
                ),
              ),

              _card(
                child: Column(
                  children: [
                    Text(
                      timerText,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE60046),
                      ),
                    ),
                    Text(
                      _isPreparing
                          ? "Preparation Time"
                          : _isRecording
                              ? "Speaking Time"
                              : "Ready",
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 155,
                      width: 155,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEF3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFCCD8),
                          width: 4,
                        ),
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        size: 72,
                        color: const Color(0xFFE60046),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!_isPreparing && !_isRecording)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoadingTopics ? null : _startPreparation,
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Color(0xFFE60046),
                          ),
                          label: Text(
                            _selectedPart == "Part 2"
                                ? "Start Preparation"
                                : "Start Speaking",
                            style: const TextStyle(
                              color: Color(0xFFE60046),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: _ashButtonStyle(),
                        ),
                      ),
                    if (_isPreparing)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _skipPreparation,
                          icon: const Icon(
                            Icons.mic,
                            color: Color(0xFFE60046),
                          ),
                          label: const Text(
                            "Skip & Start Recording",
                            style: TextStyle(
                              color: Color(0xFFE60046),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: _ashButtonStyle(),
                        ),
                      ),
                    if (_isRecording)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(
                            Icons.stop,
                            color: Color(0xFFE60046),
                          ),
                          label: const Text(
                            "Stop Recording",
                            style: TextStyle(
                              color: Color(0xFFE60046),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: _ashButtonStyle(),
                        ),
                      ),
                    if (_hasResult)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _resetAll();
                          });
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text("Retake"),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE60046),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isAnalyzing)
                _card(
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE60046)),
                      SizedBox(height: 14),
                      Text(
                        "Analyzing your speaking response...",
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              if (_transcript.isNotEmpty)
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.article_outlined, "Transcript"),
                      const SizedBox(height: 12),
                      Text(
                        _transcript,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_hasResult)
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.auto_awesome, "AI Speaking Feedback"),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            height: 95,
                            width: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFCCD8),
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _bandScore.toString(),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE60046),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Text(
                              _overallFeedback,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _feedbackLine("Fluency", _fluency),
                      _feedbackLine("Vocabulary", _vocabulary),
                      _feedbackLine("Grammar", _grammar),
                      _feedbackLine("Pronunciation", _pronunciation),
                      const SizedBox(height: 18),
                      if (_isCustomTopic)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEF3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "This is a temporary custom topic. Results will not be saved.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE60046),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                      


                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveResult,
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.white,
                          ),
                          label: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Save Result",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE60046),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_history.isNotEmpty)
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.history, "Recent Speaking History"),
                      const SizedBox(height: 12),
                      ..._history.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "${item['score'] ?? '-'}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE60046),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item['topic'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFFE60046),
        unselectedItemColor: const Color(0xFF9CA3AF),
        onTap: _goToPage,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: "Analytics",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
