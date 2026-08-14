import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reading_practice_list_page.dart';
import 'writing_page.dart';
import 'speaking_page.dart';
import 'listening/listening_page.dart';
import 'profile_page.dart';
import 'analytics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  String? avatarUrl;
  bool isLoadingScores = true;

  double writingScore = 0;
  double speakingScore = 0;
  double readingScore = 0;
  double listeningScore = 0;

  String speakingPart = "";
  @override
  void initState() {
    super.initState();
    loadProfileImage();
    fetchLatestScores();
  }

  Future<void> loadProfileImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        avatarUrl = data?['avatar_url'];
      });
    } catch (e) {
      debugPrint('Failed to load profile image: $e');
    }
  }

  Future<void> fetchLatestScores() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() => isLoadingScores = false);
      return;
    }

    try {
      final data = await supabase
          .from('homepage_scores')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      double latestWriting = 0;
      double latestSpeaking = 0;
      double latestReading = 0;
      double latestListening = 0;
      String latestSpeakingPart = "";

      for (final item in data) {
        final module = item['module'].toString().toLowerCase();
        final score = (item['band_score'] as num).toDouble();

        if (module == 'writing' && latestWriting == 0) {
          latestWriting = score;
        } else if (module == 'speaking' && latestSpeaking == 0) {
          latestSpeaking = score;
          latestSpeakingPart = item['part']?.toString() ?? "";
        } else if (module == 'reading' && latestReading == 0) {
          latestReading = score;
        } else if (module == 'listening' && latestListening == 0) {
          latestListening = score;
        }
      }

      if (!mounted) return;

      setState(() {
        writingScore = latestWriting;
        speakingScore = latestSpeaking;
        speakingPart = latestSpeakingPart;
        readingScore = latestReading;
        listeningScore = latestListening;
        isLoadingScores = false;
      });
    } catch (e) {
      debugPrint('Failed to load latest scores: $e');
      if (!mounted) return;
      setState(() => isLoadingScores = false);
    }
  }

  String scoreText(double score) {
    if (isLoadingScores) return "...";
    if (score <= 0) return "Not attempted";
    return score.toStringAsFixed(1);
  }

  Future<void> openProfilePage() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ProfilePage(
        showBottomNav: false,
      ),
    ),
  );

  loadProfileImage();
}

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await loadProfileImage();
            await fetchLatestScores();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// TOP BAR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "IELTSpire",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Blends IELTS with aspire or inspire",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: openProfilePage,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.red.shade100,
                        backgroundImage:
                            hasAvatar ? NetworkImage(avatarUrl!) : null,
                        child: !hasAvatar
                            ? const Icon(Icons.person, color: Colors.red)
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const Text(
                  "Latest Results",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                /// SCORE CARDS
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  children: [
                    ScoreCard(
                      title: "Writing",
                      score: scoreText(writingScore),
                      icon: Icons.edit,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WritingPage(),
                          ),
                        );
                        fetchLatestScores();
                      },
                    ),
                    ScoreCard(
                      title: speakingPart.isEmpty
                          ? "Speaking"
                          : "Speaking • $speakingPart",
                      score: scoreText(speakingScore),
                      icon: Icons.mic,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpeakingPage(),
                          ),
                        );
                        fetchLatestScores();
                      },
                    ),
                    ScoreCard(
                      title: "Reading",
                      score: scoreText(readingScore),
                      icon: Icons.menu_book,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingPracticeListPage(),
                          ),
                        );
                        fetchLatestScores();
                      },
                    ),
                    ScoreCard(
                      title: "Listening",
                      score: scoreText(listeningScore),
                      icon: Icons.headphones,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ListeningPage(),
                          ),
                        );
                        fetchLatestScores();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                /// QUICK ACTION TITLE
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                ActionTile(
                  title: "Practice Writing",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WritingPage(),
                      ),
                    );
                  },
                ),
                ActionTile(
                  title: "Start Speaking",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SpeakingPage(),
                      ),
                    );
                  },
                ),
                ActionTile(
                  title: "Take Reading Test",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReadingPracticeListPage(),
                      ),
                    );
                  },
                ),
                ActionTile(
                  title: "Listening Practice",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ListeningPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Every practice session brings you closer to your target IELTS band.",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (index) async {
          if (index == 1) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            );
            fetchLatestScores();
          } 
          else if (index == 2) {
            await Navigator.push(
             context,
             MaterialPageRoute(
             builder: (_) => const ProfilePage(),
            ),
          );
          loadProfileImage();
        }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
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

class ScoreCard extends StatelessWidget {
  final String title;
  final String score;
  final IconData icon;
  final VoidCallback onTap;

  const ScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasScore = score != "Not attempted" && score != "...";

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    child: Icon(icon, color: Colors.red),
                  ),
                  Flexible(
                    child: Text(
                      score,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: hasScore ? 18 : 11,
                        fontWeight: FontWeight.bold,
                        color: hasScore ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
