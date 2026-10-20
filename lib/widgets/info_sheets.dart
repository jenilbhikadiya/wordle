import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../game/game_logic.dart';
import '../theme/app_theme.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hard mode'),
                subtitle: const Text(
                  'Letters you have found must be used in later guesses. '
                  'Wins earn 3 bonus points.',
                ),
                value: settings.hardMode,
                onChanged: settings.setHardMode,
              ),
              const Divider(height: 24),
              Text('Appearance', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Dark'),
                  ),
                ],
                selected: {settings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showHelpSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _HelpSheet(),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to play', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Guess the word in 6 tries. Each guess must be a real word.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'After each guess the tiles change colour to show how close '
              'you were.',
              style: muted,
            ),
            const SizedBox(height: 20),
            const _Example(
              word: 'crane',
              index: 0,
              state: LetterState.correct,
              text: 'C is in the word and in the right spot.',
            ),
            const _Example(
              word: 'pilot',
              index: 2,
              state: LetterState.present,
              text: 'L is in the word but in the wrong spot.',
            ),
            const _Example(
              word: 'vague',
              index: 3,
              state: LetterState.absent,
              text: 'U is not in the word at all.',
            ),
            const Divider(height: 32),
            _Bullet(
              icon: Icons.today_rounded,
              title: 'Daily puzzle',
              text:
                  'One word a day, the same for everyone. It can be 4, 5 or '
                  '6 letters. A new one unlocks at midnight.',
            ),
            _Bullet(
              icon: Icons.local_fire_department_rounded,
              title: 'Day streak',
              text: 'Play the daily every day to grow your streak.',
            ),
            _Bullet(
              icon: Icons.calendar_month_rounded,
              title: 'Calendar',
              text:
                  'Catch up on days you missed. These count in your stats '
                  'but not your streak.',
            ),
            _Bullet(
              icon: Icons.all_inclusive_rounded,
              title: 'Practice',
              text: 'Play as many random 4, 5 or 6 letter words as you like.',
            ),
            _Bullet(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Hints',
              text: 'Reveal a letter, up to 2 per game. Each costs 2 points.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Example extends StatelessWidget {
  final String word;
  final int index;
  final LetterState state;
  final String text;

  const _Example({
    required this.word,
    required this.index,
    required this.state,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final fill = switch (state) {
      LetterState.correct => colors.correct,
      LetterState.present => colors.present,
      LetterState.absent => colors.absent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < word.length; i++)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? fill : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: i == index ? fill : colors.filledBorder,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    word[i].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: i == index ? colors.onTile : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Bullet({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
