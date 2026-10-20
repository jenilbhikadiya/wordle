import 'package:flutter/material.dart';

import '../utils/stats_service.dart';

/// Played / win % / streak numbers plus a guess distribution chart.
class StatsPanel extends StatelessWidget {
  final GameStats stats;
  final Color accentColor;
  // 1-based guess count to highlight, e.g. the game that was just won.
  final int? highlightAttempt;

  const StatsPanel({
    super.key,
    required this.stats,
    this.accentColor = const Color(0xFF0ff4c6),
    this.highlightAttempt,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.distribution.fold<int>(1, (a, b) => b > a ? b : a);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatTile(value: '${stats.played}', label: 'PLAYED', color: accentColor),
            _StatTile(value: '${stats.winPercent}', label: 'WIN %', color: accentColor),
            _StatTile(value: '${stats.currentStreak}', label: 'STREAK', color: accentColor),
            _StatTile(value: '${stats.maxStreak}', label: 'BEST', color: accentColor),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'GUESS DISTRIBUTION',
          style: TextStyle(
            color: accentColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 8),
        for (int i = 0; i < stats.distribution.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final count = stats.distribution[i];
                    final highlighted = highlightAttempt == i + 1;
                    final width = 24 +
                        (constraints.maxWidth - 24) * (count / maxCount);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: width,
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: highlighted
                              ? accentColor.withOpacity(0.8)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: highlighted ? Color(0xFF0f0f1e) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Stats for every word length, opened from the home screen.
class StatsDialog extends StatefulWidget {
  const StatsDialog({super.key});

  @override
  State<StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends State<StatsDialog> {
  int _length = 5;
  final Map<int, GameStats> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final len in [4, 5, 6]) {
      _stats[len] = await StatsService.getStats(len);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0ff4c6);
    final stats = _stats[_length];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent, width: 3),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: accent),
                SizedBox(width: 8),
                Text(
                  'STATISTICS',
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: accent),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [4, 5, 6].map((len) {
                final selected = len == _length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$len LETTERS'),
                    selected: selected,
                    onSelected: (_) => setState(() => _length = len),
                    selectedColor: accent.withOpacity(0.3),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: accent.withOpacity(selected ? 1 : 0.4)),
                    labelStyle: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            if (stats == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: accent),
              )
            else
              StatsPanel(stats: stats),
          ],
        ),
      ),
    );
  }
}
