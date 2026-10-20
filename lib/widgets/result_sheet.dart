import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import 'stats_view.dart';

enum ResultAction { playAgain, close }

/// End-of-game summary: the answer, points, streak, stats and sharing.
Future<ResultAction?> showResultSheet(
  BuildContext context,
  GameController game,
  GameResult result,
) {
  return showModalBottomSheet<ResultAction>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ResultSheet(game: game, result: result),
  );
}

class _ResultSheet extends StatelessWidget {
  final GameController game;
  final GameResult result;

  const _ResultSheet({required this.game, required this.result});

  static const _praise = [
    'Genius!',
    'Magnificent!',
    'Impressive!',
    'Splendid!',
    'Great!',
    'Phew!',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final won = result.won;
    final title = won ? _praise[game.guesses.length - 1] : 'So close!';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              won
                  ? 'Solved in ${game.guesses.length}/${GameController.maxAttempts}'
                  : 'The word was',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!won) ...[
              const SizedBox(height: 10),
              Center(child: _AnswerTiles(word: game.target)),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result.pointsEarned > 0)
                  _Pill(
                    icon: Icons.stars_rounded,
                    color: theme.colorScheme.primary,
                    label: '+${result.pointsEarned} points',
                  ),
                if (game.isDaily)
                  _Pill(
                    icon: Icons.local_fire_department_rounded,
                    color: colors.streak,
                    label: '${result.dayStreak} day streak',
                  ),
                if (game.hardMode)
                  _Pill(
                    icon: Icons.bolt_rounded,
                    color: colors.present,
                    label: 'Hard mode',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            StatsView(
              stats: result.stats,
              highlight: won ? game.guesses.length : null,
            ),
            const SizedBox(height: 24),
            if (game.isDaily) ...[
              const _NextPuzzleCountdown(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: game.share()),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Result copied to clipboard'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      game.isDaily
                          ? ResultAction.close
                          : ResultAction.playAgain,
                    ),
                    icon: Icon(
                      game.isDaily
                          ? Icons.check_rounded
                          : Icons.refresh_rounded,
                    ),
                    label: Text(game.isDaily ? 'Done' : 'Play again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerTiles extends StatelessWidget {
  final String word;
  const _AnswerTiles({required this.word});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ch in word.split(''))
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.correct,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ch.toUpperCase(),
              style: TextStyle(
                color: colors.onTile,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Pill({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Live countdown to midnight, when the next daily unlocks.
class _NextPuzzleCountdown extends StatefulWidget {
  const _NextPuzzleCountdown();

  @override
  State<_NextPuzzleCountdown> createState() => _NextPuzzleCountdownState();
}

class _NextPuzzleCountdownState extends State<_NextPuzzleCountdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    final text =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'Next puzzle in',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            text,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
