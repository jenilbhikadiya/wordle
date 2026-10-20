import 'package:flutter/material.dart';

import '../data/storage.dart';
import '../models/game_stats.dart';
import '../theme/app_theme.dart';

/// Played / win % / streak numbers and a guess distribution chart.
class StatsView extends StatelessWidget {
  final GameStats stats;
  // 1-based guess count to highlight, e.g. the game that was just won.
  final int? highlight;

  const StatsView({super.key, required this.stats, this.highlight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = stats.distribution.fold<int>(1, (a, b) => b > a ? b : a);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Number(value: '${stats.played}', label: 'Played'),
            _Number(value: '${stats.winPercent}', label: 'Win %'),
            _Number(value: '${stats.currentStreak}', label: 'Current\nstreak'),
            _Number(value: '${stats.maxStreak}', label: 'Max\nstreak'),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Guess distribution',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (stats.wins == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Win a game to see how many guesses you usually need.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (int i = 0; i < stats.distribution.length; i++)
            _Bar(
              label: '${i + 1}',
              count: stats.distribution[i],
              fraction: stats.distribution[i] / maxCount,
              highlighted: highlight == i + 1,
            ),
      ],
    );
  }
}

class _Number extends StatelessWidget {
  final String value;
  final String label;

  const _Number({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final bool highlighted;

  const _Bar({
    required this.label,
    required this.count,
    required this.fraction,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: 28 + (c.maxWidth - 28) * fraction,
                    height: 24,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: highlighted ? colors.correct : colors.absent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onTile,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats for every word length, opened from the home screen.
Future<void> showStatsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _StatsSheet(),
  );
}

class _StatsSheet extends StatefulWidget {
  const _StatsSheet();

  @override
  State<_StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends State<_StatsSheet> {
  int _length = 5;
  final Map<int, GameStats> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final len in [4, 5, 6]) {
      _stats[len] = await Storage.instance.stats(len);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats[_length];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Statistics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 4, label: Text('4 letters')),
                ButtonSegment(value: 5, label: Text('5 letters')),
                ButtonSegment(value: 6, label: Text('6 letters')),
              ],
              selected: {_length},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _length = s.first),
            ),
            const SizedBox(height: 24),
            if (stats == null)
              const Center(child: CircularProgressIndicator())
            else
              StatsView(stats: stats),
          ],
        ),
      ),
    );
  }
}
