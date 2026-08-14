import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'profile_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool isLoading = true;

  double readingScore = 0;
  double writingScore = 0;
  double speakingScore = 0;
  double listeningScore = 0;
  double overallBand = 0;
  double overallChange = 0;

  List<double> readingTrend = [];
  List<double> writingTrend = [];
  List<double> speakingTrend = [];
  List<double> listeningTrend = [];

  static const writingColor = Color(0xFFEF233C);
  static const speakingColor = Color(0xFF2563EB);
  static const readingColor = Color(0xFF7C3AED);
  static const listeningColor = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _fetchAllScores();
  }

  double? _toScore(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  double _ceilToHalf(double value) {
    if (value <= 0) return 0;
    return (value * 2).ceil() / 2;
  }

  double _avg(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _bandText(double value) {
    final v = value.abs() < 0.0001 ? 0.0 : value;
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String _changeText() {
    if (overallChange > 0) return '+${_bandText(overallChange)}';
    return _bandText(overallChange);
  }

  List<double> _lastFourOldToNew(List<double> scores) {
    return scores.take(4).toList().reversed.toList();
  }

  Future<void> _fetchAllScores() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final rows = await Supabase.instance.client
          .from('ielts_scores')
          .select('module, band_score, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final reading = <double>[];
      final writing = <double>[];
      final speaking = <double>[];
      final listening = <double>[];

      for (final item in rows) {
        final module = (item['module'] ?? '').toString().trim().toLowerCase();
        final score = _toScore(item['band_score']);

        if (score == null || score < 0 || score > 9) continue;

        if (module.contains('reading')) {
          reading.add(score);
        } else if (module.contains('writing')) {
          writing.add(score);
        } else if (module.contains('speaking')) {
          speaking.add(score);
        } else if (module.contains('listening')) {
          listening.add(score);
        }
      }

      final latestReading = reading.isNotEmpty ? reading.first : 0.0;
      final latestWriting = writing.isNotEmpty ? writing.first : 0.0;
      final latestSpeaking = speaking.isNotEmpty ? speaking.first : 0.0;
      final latestListening = listening.isNotEmpty ? listening.first : 0.0;

      final latestScores = <double>[
        if (reading.isNotEmpty) latestReading,
        if (writing.isNotEmpty) latestWriting,
        if (speaking.isNotEmpty) latestSpeaking,
        if (listening.isNotEmpty) latestListening,
      ];

      final latestForChange = <double>[];
      final previousForChange = <double>[];

      void addChange(List<double> list) {
        if (list.length >= 2) {
          latestForChange.add(list[0]);
          previousForChange.add(list[1]);
        }
      }

      addChange(reading);
      addChange(writing);
      addChange(speaking);
      addChange(listening);

      final latestRoundedAvg = _ceilToHalf(_avg(latestForChange));
      final previousRoundedAvg = _ceilToHalf(_avg(previousForChange));

      if (!mounted) return;

      setState(() {
        readingScore = latestReading;
        writingScore = latestWriting;
        speakingScore = latestSpeaking;
        listeningScore = latestListening;

        overallBand = _ceilToHalf(_avg(latestScores));
        overallChange =
            latestForChange.isEmpty ? 0 : latestRoundedAvg - previousRoundedAvg;

        readingTrend = _lastFourOldToNew(reading);
        writingTrend = _lastFourOldToNew(writing);
        speakingTrend = _lastFourOldToNew(speaking);
        listeningTrend = _lastFourOldToNew(listening);

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load analytics: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToPage(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } else if (index == 1) {
      _fetchAllScores();
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 600;

    final moduleScores = [
      _ModuleScore('Writing', writingScore, writingColor),
      _ModuleScore('Speaking', speakingScore, speakingColor),
      _ModuleScore('Reading', readingScore, readingColor),
      _ModuleScore('Listening', listeningScore, listeningColor),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F8),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: RefreshIndicator(
                color: Colors.red,
                onRefresh: _fetchAllScores,
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          isPhone ? 14 : 22,
                          20,
                          isPhone ? 14 : 22,
                          150,
                        ),
                        child: Column(
                          children: [
                            _summaryCards(isPhone),
                            const SizedBox(height: 24),
                            _ChartCard(
                              title: 'Performance Trends',
                              height: isPhone ? 365 : 345,
                              child: _TrendChart(
                                readingValues: readingTrend,
                                writingValues: writingTrend,
                                speakingValues: speakingTrend,
                                listeningValues: listeningTrend,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _ChartCard(
                              title: 'Current Module Scores',
                              height: isPhone ? 345 : 335,
                              child: _BarChart(scores: moduleScores),
                            ),
                            const SizedBox(height: 24),
                            _ChartCard(
                              title: 'Module Score Analysis',
                              height: isPhone ? 500 : 500,
                              child: _RingAnalysis(
                                scores: moduleScores,
                                overallBand: overallBand,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(top: false, child: _bottomNav()),
    );
  }

  Widget _summaryCards(bool isPhone) {
    final cards = [
      _GradientCard(
        title: 'Overall Band',
        value: _bandText(overallBand),
        subtitle: 'Average of latest module scores',
        colors: const [Color(0xFFFF2A2A), Color(0xFFE9001E)],
      ),
      _GradientCard(
        title: 'Overall Change',
        value: _changeText(),
        subtitle: 'Rounded latest average vs previous',
        colors: const [Color(0xFFFF2A2A), Color(0xFFF00058)],
      ),
    ];

    if (isPhone) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 14),
          cards[1],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }

  Widget _topBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmall ? 4 : 8,
        10,
        isSmall ? 10 : 18,
        14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: isSmall ? 24 : 26),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmall ? 20 : 23,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF071323),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Performance insights & trends',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchAllScores,
            icon: const Icon(Icons.refresh, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      onTap: _goToPage,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), label: 'Analytics'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}

class _ModuleScore {
  final String label;
  final double score;
  final Color color;

  const _ModuleScore(this.label, this.score, this.color);
}

class _GradientCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final List<Color> colors;

  const _GradientCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Container(
      height: isPhone ? 170 : 165,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 18 : 22,
        vertical: isPhone ? 16 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(64),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isPhone ? 15 : 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isPhone ? 40 : 44,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xF2FFFFFF),
              fontSize: isPhone ? 13 : 15,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 380;

    return Container(
      height: height,
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9DE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0AF44336),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmall ? 20 : 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF071323),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<double> readingValues;
  final List<double> writingValues;
  final List<double> speakingValues;
  final List<double> listeningValues;

  const _TrendChart({
    required this.readingValues,
    required this.writingValues,
    required this.speakingValues,
    required this.listeningValues,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(
        readingValues: readingValues,
        writingValues: writingValues,
        speakingValues: speakingValues,
        listeningValues: listeningValues,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> readingValues;
  final List<double> writingValues;
  final List<double> speakingValues;
  final List<double> listeningValues;

  const _TrendPainter({
    required this.readingValues,
    required this.writingValues,
    required this.speakingValues,
    required this.listeningValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final isSmall = size.width < 500;
    final left = 42.0;
    final top = 12.0;
    final right = size.width - 10;
    final bottom = size.height - (isSmall ? 108 : 84);

    final all = [readingValues, writingValues, speakingValues, listeningValues];
    final count = all.fold<int>(0, (m, v) => max(m, v.length));

    if (count == 0) {
      _drawText(canvas, textPainter, 'No score data yet',
          Offset(size.width / 2, size.height / 2), 16, Colors.grey,
          center: true, bold: true);
      return;
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + i * ((bottom - top) / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    double xAt(int i) {
      if (count <= 1) return (left + right) / 2;
      return left + i * ((right - left) / (count - 1));
    }

    for (int i = 0; i < count; i++) {
      final x = xAt(i);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), gridPaint);
    }

    final yLabels = ['9', '6', '3', '0'];
    for (int i = 0; i < yLabels.length; i++) {
      final y = top + i * ((bottom - top) / 3);
      _drawText(
          canvas, textPainter, yLabels[i], Offset(15, y - 8), 12, Colors.grey);
    }

    void drawSeries(List<double> values, Color color) {
      if (values.isEmpty) return;

      final points = <Offset>[];
      final startIndex = count - values.length;

      for (int i = 0; i < values.length; i++) {
        final value = values[i].clamp(0.0, 9.0).toDouble();
        final x = xAt(startIndex + i);
        final y = bottom - (value / 9) * (bottom - top);
        points.add(Offset(x, y));
      }

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (points.length > 1) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, linePaint);
      }

      for (final p in points) {
        canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          5.5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    drawSeries(writingValues, _AnalyticsPageState.writingColor);
    drawSeries(speakingValues, _AnalyticsPageState.speakingColor);
    drawSeries(readingValues, _AnalyticsPageState.readingColor);
    drawSeries(listeningValues, _AnalyticsPageState.listeningColor);

    final labels = count == 1
        ? ['Latest']
        : count == 2
            ? ['Previous', 'Latest']
            : count == 3
                ? ['A1', 'A2', 'Latest']
                : ['A1', 'A2', 'A3', 'Latest'];

    for (int i = 0; i < count; i++) {
      _drawText(
        canvas,
        textPainter,
        labels[i],
        Offset(xAt(i), bottom + 10),
        isSmall ? 10 : 11,
        Colors.grey,
        center: true,
      );
    }

    final legends = [
      _ModuleScore('Writing', 0, _AnalyticsPageState.writingColor),
      _ModuleScore('Speaking', 0, _AnalyticsPageState.speakingColor),
      _ModuleScore('Reading', 0, _AnalyticsPageState.readingColor),
      _ModuleScore('Listening', 0, _AnalyticsPageState.listeningColor),
    ];

    void legend(_ModuleScore item, double x, double y) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 12, y),
        Paint()
          ..color = item.color
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(x + 6, y), 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x + 6, y),
        3,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawText(canvas, textPainter, item.label, Offset(x + 16, y - 8),
          isSmall ? 11 : 12, item.color,
          bold: true);
    }

    if (isSmall) {
      final row1Y = size.height - 58;
      final row2Y = size.height - 28;
      final col1X = left;
      final col2X = left + ((right - left) / 2);
      legend(legends[0], col1X, row1Y);
      legend(legends[1], col2X, row1Y);
      legend(legends[2], col1X, row2Y);
      legend(legends[3], col2X, row2Y);
    } else {
      double x = left;
      final y = size.height - 28;
      for (final item in legends) {
        legend(item, x, y);
        x += item.label.length * 8 + 52;
      }
    }
  }

  void _drawText(
    Canvas canvas,
    TextPainter painter,
    String text,
    Offset offset,
    double size,
    Color color, {
    bool center = false,
    bool bold = false,
  }) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      center
          ? Offset(
              offset.dx - painter.width / 2, offset.dy - painter.height / 2)
          : offset,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.readingValues != readingValues ||
        oldDelegate.writingValues != writingValues ||
        oldDelegate.speakingValues != speakingValues ||
        oldDelegate.listeningValues != listeningValues;
  }
}

class _BarChart extends StatelessWidget {
  final List<_ModuleScore> scores;

  const _BarChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarPainter(scores: scores),
      child: const SizedBox.expand(),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<_ModuleScore> scores;

  const _BarPainter({required this.scores});

  String _text(double value) {
    final v = value.clamp(0.0, 9.0).toDouble();
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final left = 42.0;
    final top = 10.0;
    final right = size.width - 12;
    final bottom = size.height - 54;
    final chartWidth = right - left;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + i * ((bottom - top) / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    final yLabels = ['9', '6', '3', '0'];
    for (int i = 0; i < yLabels.length; i++) {
      final y = top + i * ((bottom - top) / 3);
      _drawText(
          canvas, textPainter, yLabels[i], Offset(15, y - 8), 12, Colors.grey);
    }

    double barWidth = min(46, chartWidth / 6);
    double gap = (chartWidth - barWidth * 4) / 3;
    if (gap < 10) {
      gap = 10;
      barWidth = (chartWidth - gap * 3) / 4;
    }
    final totalWidth = barWidth * 4 + gap * 3;
    final startX = left + (chartWidth - totalWidth) / 2;

    for (int i = 0; i < scores.length; i++) {
      final item = scores[i];
      final value = item.score.clamp(0.0, 9.0).toDouble();
      final h = (value / 9) * (bottom - top);
      final x = startX + i * (barWidth + gap);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - h, barWidth, h),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, Paint()..color = item.color);

      _drawText(
        canvas,
        textPainter,
        _text(value),
        Offset(x + barWidth / 2, max(top + 4, bottom - h - 16)),
        12,
        const Color(0xFF111827),
        center: true,
        bold: true,
      );

      _drawText(
        canvas,
        textPainter,
        item.label,
        Offset(x + barWidth / 2, bottom + 18),
        9.5,
        Colors.grey,
        center: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    TextPainter painter,
    String text,
    Offset offset,
    double size,
    Color color, {
    bool center = false,
    bool bold = false,
  }) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      center
          ? Offset(
              offset.dx - painter.width / 2, offset.dy - painter.height / 2)
          : offset,
    );
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    return oldDelegate.scores != scores;
  }
}

class _RingAnalysis extends StatelessWidget {
  final List<_ModuleScore> scores;
  final double overallBand;

  const _RingAnalysis({required this.scores, required this.overallBand});

  String _text(double value) {
    final v = value.clamp(0.0, 9.0).toDouble();
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: isPhone ? 235 : 255,
          width: isPhone ? 235 : 255,
          child: CustomPaint(
            painter: _RingPainter(scores: scores, overallBand: overallBand),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final oneColumn = constraints.maxWidth < 330;
            final itemWidth = oneColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 14) / 2;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: scores
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: Row(
                        children: [
                          CircleAvatar(radius: 7, backgroundColor: item.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.label}: ${_text(item.score)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<_ModuleScore> scores;
  final double overallBand;

  const _RingPainter({required this.scores, required this.overallBand});

  String _text(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = diameter < 230 ? 9.0 : 10.0;
    final gap = diameter < 230 ? 6.0 : 7.0;
    final outerRadius = diameter / 2 - 16;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E7EB);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < scores.length; i++) {
      final radius = outerRadius - i * (strokeWidth + gap);
      if (radius <= 0) continue;

      canvas.drawCircle(center, radius, backgroundPaint);

      final value = scores[i].score.clamp(0.0, 9.0).toDouble();
      if (value <= 0) continue;

      progressPaint.color = scores[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        (value / 9) * 2 * pi,
        false,
        progressPaint,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: _text(overallBand),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - 25),
    );

    textPainter.text = const TextSpan(
      text: 'Average',
      style: TextStyle(color: Colors.grey, fontSize: 13),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + 9),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.scores != scores ||
        oldDelegate.overallBand != overallBand;
  }
}
