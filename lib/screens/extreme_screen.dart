import 'package:flutter/material.dart';

import '../data/storage.dart';
import '../game/extreme_levels.dart';
import '../theme/app_theme.dart';
import '../theme/premium_route.dart';
import 'game_screen.dart';

/// The 50 Extreme levels, grouped by tier. Open it with [premiumRoute].
class ExtremeScreen extends StatefulWidget {
  const ExtremeScreen({super.key});

  @override
  State<ExtremeScreen> createState() => _ExtremeScreenState();
}

class _ExtremeScreenState extends State<ExtremeScreen> {
  int _cleared = 0;
  Map<int, int> _best = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cleared = await Storage.instance.extremeCleared();
    final best = await Storage.instance.extremeBest();
    if (!mounted) return;
    setState(() {
      _cleared = cleared;
      _best = best;
    });
  }

  Future<void> _play(ExtremeLevel level) async {
    if (!isExtremeUnlocked(level.number, _cleared)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Clear level ${level.number - 1} first')),
        );
      return;
    }
    await Navigator.push(context, premiumRoute(GameScreen(level: level)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const GoldText('EXTREME', size: 22),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Fifty of the hardest words we could find. Every level '
                      'is played in hard mode, and the rules tighten with '
                      'each tier. A lost level keeps its word secret, so '
                      'you can try again.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Progress(cleared: _cleared),
                    for (final tier in ExtremeTier.values) ...[
                      const SizedBox(height: 28),
                      _TierHeader(tier: tier, cleared: _cleared),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final level in extremeLevels.where(
                            (l) => l.tier == tier,
                          ))
                            _LevelMedal(
                              level: level,
                              best: _best[level.number],
                              unlocked: isExtremeUnlocked(
                                level.number,
                                _cleared,
                              ),
                              onTap: () => _play(level),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text painted with the gold gradient.
class GoldText extends StatelessWidget {
  final String text;
  final double size;
  const GoldText(this.text, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.goldGradient.createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: size * 0.18,
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int cleared;
  const _Progress({required this.cleared});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = extremeLevels.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                '$cleared of $total cleared',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: theme.colorScheme.surfaceContainer),
                FractionallySizedBox(
                  widthFactor: cleared / total,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.goldGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierHeader extends StatelessWidget {
  final ExtremeTier tier;
  final int cleared;
  const _TierHeader({required this.tier, required this.cleared});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = (cleared - tier.firstLevel + 1).clamp(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GoldText(tier.name.toUpperCase(), size: 15),
            const SizedBox(width: 10),
            Text(
              'Levels ${tier.firstLevel}–${tier.lastLevel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '$done/10',
              style: theme.textTheme.labelLarge?.copyWith(
                color: done == 10
                    ? AppTheme.gold
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(tier.tagline, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.amethyst.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tier.rules,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFC4B1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// One level: gold when cleared, outlined when next up, dim when locked.
class _LevelMedal extends StatelessWidget {
  final ExtremeLevel level;
  final int? best;
  final bool unlocked;
  final VoidCallback onTap;

  const _LevelMedal({
    required this.level,
    required this.best,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleared = best != null;
    final current = unlocked && !cleared;

    final BoxDecoration decoration;
    final Color textColor;
    if (cleared) {
      decoration = BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      );
      textColor = const Color(0xFF1C1505);
    } else if (current) {
      decoration = BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.35),
            blurRadius: 14,
          ),
        ],
      );
      textColor = AppTheme.gold;
    } else {
      decoration = BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      );
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return Semantics(
      button: true,
      label:
          'Level ${level.number}, '
          '${cleared
              ? 'cleared in $best'
              : unlocked
              ? 'ready'
              : 'locked'}',
      // Its own Material keeps the Ink clipped to the scrolling list
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: decoration,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!unlocked)
                  Icon(Icons.lock_rounded, size: 16, color: textColor)
                else
                  Text(
                    '${level.number}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (cleared)
                  Text(
                    '$best/${level.maxAttempts}',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else if (!unlocked)
                  Text(
                    '${level.number}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
