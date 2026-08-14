import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSpeakingPage extends StatefulWidget {
  const AdminSpeakingPage({super.key});

  @override
  State<AdminSpeakingPage> createState() => _AdminSpeakingPageState();
}

class _AdminSpeakingPageState extends State<AdminSpeakingPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedPart = "Part 1";

  List<Map<String, dynamic>> topics = [];

  static const bgColor = Color(0xFFF5F6FA);
  static const primaryColor = Color(0xFFFF3B30);
  static const lightPrimary = Color(0xFFFFE8E6);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);
  static const snackBarColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    setState(() => isLoading = true);

    try {
      final data = await supabase
          .from('speaking_topics')
          .select()
          .eq('part', selectedPart)
          .order('created_at', ascending: false);

      setState(() {
        topics = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showMessage("Failed to load topics: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _deleteTopic(String id) async {
    try {
      await supabase.from('speaking_topics').delete().eq('id', id);
      _showMessage("Topic deleted");
      await _fetchTopics();
    } catch (e) {
      _showMessage("Delete failed: $e");
    }
  }

  void _changePart(String part) {
    setState(() => selectedPart = part);
    _fetchTopics();
  }

  void _openTopicSheet({Map<String, dynamic>? topic}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _TopicFormSheet(
        selectedPart: selectedPart,
        topic: topic,
        onSaved: _fetchTopics,
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> topic) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Topic"),
          content: const Text("Are you sure you want to delete this topic?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteTopic(topic['id'].toString());
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: snackBarColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _partButton(String part) {
    final selected = selectedPart == part;

    return Expanded(
      child: GestureDetector(
        onTap: () => _changePart(part),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: lightPrimary,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: primaryColor, width: 2)
                : null,
          ),
          child: Text(
            part,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topicCard(Map<String, dynamic> item) {
    final topic = item['topic']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final difficulty = item['difficulty']?.toString() ?? 'medium';
    final cuePoints = item['cue_points']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.4,
                ),
              ),
              if (selectedPart == "Part 2" && cuePoints.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "You should say:\n$cuePoints",
                    style: const TextStyle(
                      color: primaryColor,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              

Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    _chip(selectedPart),

    if (category.isNotEmpty)
      _chip(category),

    _chip(difficulty),
  ],
),

const SizedBox(height: 8),

Align(
  alignment: Alignment.centerRight,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: () => _openTopicSheet(topic: item),
        icon: const Icon(
          Icons.edit_outlined,
          color: primaryColor,
        ),
      ),
      IconButton(
        onPressed: () => _confirmDelete(item),
        icon: const Icon(
          Icons.delete_outline,
          color: primaryColor,
        ),
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


  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: lightPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.mic_none, size: 55, color: primaryColor.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text(
            "No speaking topics yet",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add a new topic for this speaking part.",
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
    title: const Text(
    'Admin Speaking',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      ),
    ),
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    actions: [
      IconButton(
        onPressed: _fetchTopics,
        icon: const Icon(Icons.refresh),
        color: Colors.white,
        ),
      ],
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTopicSheet(),
        backgroundColor: lightPrimary,
        elevation: 0,
        icon: const Icon(Icons.add, color: primaryColor),
        label: const Text(
          "Add Topic",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final bool isMobile = screenWidth < 600;

          final double contentWidth = isMobile
          ? screenWidth
             : (screenWidth * 0.6).clamp(500.0, 900.0).toDouble();
          final bool isSmallScreen = screenWidth <= 320;

          return RefreshIndicator(
            onRefresh: _fetchTopics,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 18,
                vertical: 18,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: lightPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Add, edit, and delete IELTS speaking topics. Part 2 can include cue points like the real IELTS cue card.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _partButton("Part 1"),
                          _partButton("Part 2"),
                          _partButton("Part 3"),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "$selectedPart Topics (${topics.length})",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(color: primaryColor),
                          ),
                        )
                      else if (topics.isEmpty)
                        _emptyState()
                      else
                        ...topics.map(_topicCard),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopicFormSheet extends StatefulWidget {
  final String selectedPart;
  final Map<String, dynamic>? topic;
  final VoidCallback onSaved;

  const _TopicFormSheet({
    required this.selectedPart,
    required this.topic,
    required this.onSaved,
  });

  @override
  State<_TopicFormSheet> createState() => _TopicFormSheetState();
}

class _TopicFormSheetState extends State<_TopicFormSheet> {
  final supabase = Supabase.instance.client;

  final topicController = TextEditingController();
  final cuePointsController = TextEditingController();
  final categoryController = TextEditingController();

  String selectedPart = "Part 1";
  String selectedDifficulty = "medium";
  bool isSaving = false;

  static const primaryColor = Color(0xFFFF3B30);
  static const bgColor = Color(0xFFF5F6FA);
  static const textColor = Color(0xFF202124);
  static const subTextColor = Color(0xFF6B7280);

  final List<String> parts = ["Part 1", "Part 2", "Part 3"];
  final List<String> difficulties = ["easy", "medium", "hard"];

  bool get isEdit => widget.topic != null;

  @override
  void initState() {
    super.initState();

    selectedPart = widget.topic?['part']?.toString() ?? widget.selectedPart;
    selectedDifficulty = widget.topic?['difficulty']?.toString() ?? "medium";

    topicController.text = widget.topic?['topic']?.toString() ?? '';
    cuePointsController.text = widget.topic?['cue_points']?.toString() ?? '';
    categoryController.text = widget.topic?['category']?.toString() ?? '';
  }

  @override
  void dispose() {
    topicController.dispose();
    cuePointsController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveTopic() async {
    final topicText = topicController.text.trim();
    final cuePointsText = cuePointsController.text.trim();
    final categoryText = categoryController.text.trim();

    if (topicText.isEmpty) {
      _showMessage("Topic cannot be empty");
      return;
    }

    setState(() => isSaving = true);

    try {
      final data = {
        'part': selectedPart,
        'topic': topicText,
        'cue_points': selectedPart == "Part 2" ? cuePointsText : '',
        'category': categoryText,
        'difficulty': selectedDifficulty,
      };

      if (isEdit) {
        await supabase
            .from('speaking_topics')
            .update(data)
            .eq('id', widget.topic!['id']);
      } else {
        await supabase.from('speaking_topics').insert(data);
      }

      if (!mounted) return;

      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      _showMessage("Save failed: $e");
    }

    if (mounted) setState(() => isSaving = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE5E7EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: subTextColor),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? "Edit Speaking Topic" : "Add Speaking Topic",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 18),
            _dropdown(
              label: "Speaking Part",
              value: selectedPart,
              items: parts,
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedPart = value);
                }
              },
            ),
            const SizedBox(height: 14),
            _inputField(
              label: selectedPart == "Part 2"
                  ? "Cue Card Topic"
                  : "Topic / Question",
              icon: Icons.topic_outlined,
              controller: topicController,
              maxLines: 3,
            ),
            if (selectedPart == "Part 2") ...[
              const SizedBox(height: 14),
              _inputField(
                label: "Cue Points",
                icon: Icons.format_list_bulleted,
                controller: cuePointsController,
                maxLines: 5,
                hintText:
                    "where you went\nwho you went with\nwhat you did\nwhy it was memorable",
              ),
            ],
            const SizedBox(height: 14),
            _inputField(
              label: "Category",
              icon: Icons.category_outlined,
              controller: categoryController,
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: "Difficulty",
              value: selectedDifficulty,
              items: difficulties,
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedDifficulty = value);
                }
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : _saveTopic,
                icon: isSaving
                    ? const SizedBox.shrink()
                    : Icon(
                        isEdit ? Icons.save_outlined : Icons.add,
                        color: primaryColor,
                      ),
                label: isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? "Save Changes" : "Add Topic",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}