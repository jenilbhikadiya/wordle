import 'dart:async';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../data/storage.dart';
import '../data/word_repository.dart';
import '../game/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/info_sheets.dart';
import '../widgets/stats_view.dart';
import 'calendar_screen.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _points = 0;
  int _streak = 0;
  int? _todayLength;
  int? _todayResult;
  bool _todayStarted = false;
  Map<String, int> _weekResults = {};
  Set<String> _playedDays = {};
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = dayOnly(DateTime.now());
    _load();
    _maybeShowHelp();
  }

  Future<void> _maybeShowHelp() async {
    if (await Storage.instance.seenHelp()) return;
    await Storage.instance.setSeenHelp();
    if (mounted) showHelpSheet(context);
  }

  List<DateTime> get _week => [
    for (int i = 6; i >= 0; i--)
      DateTime(_today.year, _today.month, _today.day - i),
  ];

  Future<void> _load() async {
    _today = dayOnly(DateTime.now());
    final storage = Storage.instance;
    final key = dateKey(_today);
    final schedule = await WordRepository.instance.dailySchedule();
    final points = await storage.points();
    final played = await storage.playedDays();
    final result = await storage.dailyResult(key);
    final started = (await storage.dailyGuesses(key)).isNotEmpty;
    final week = await storage.dailyResults(_week.map(dateKey));
    if (!mounted) return;
    setState(() {
      _points = points;
      _playedDays = played;
      _streak = dayStreak(played, DateTime.now());
      _todayLength = dailyWord(schedule, _today).length;
      _todayResult = result;
      _todayStarted = started;
      _weekResults = week;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  void _playDaily() => _open(
    GameScreen(dailyDate: _today, hardMode: AppSettings.instance.hardMode),
  );

  void _playPractice(int length) => _open(
    GameScreen(wordLength: length, hardMode: AppSettings.instance.hardMode),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const _Logo(),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showHelpSheet(context),
          ),
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () => showStatsSheet(context),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => showSettingsSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.local_fire_department_rounded,
                              color: GameColors.of(context).streak,
                              value: '$_streak',
                              label: 'day streak',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.stars_rounded,
                              color: theme.colorScheme.primary,
                              value: '$_points',
                              label: 'points',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DailyCard(
                        number: dailyNumber(_today),
                        date: _today,
                        length: _todayLength,
                        result: _todayResult,
                        started: _todayStarted,
                        onPlay: _playDaily,
                      ),
                      const SizedBox(height: 16),
                      _WeekCard(
                        days: _week,
                        results: _weekResults,
                        playedDays: _playedDays,
                        onOpenCalendar: () => _open(
                          CalendarScreen(
                            hardMode: AppSettings.instance.hardMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('Practice', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        'Unlimited random words. Pick a length.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final len
                              in WordRepository.supportedLengths) ...[
                            if (len != 4) const SizedBox(width: 12),
                            Expanded(
                              child: _PracticeCard(
                                length: len,
                                onTap: () => _playPractice(len),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListenableBuilder(
                        listenable: AppSettings.instance,
                        builder: (context, _) => _HardModeRow(
                          enabled: AppSettings.instance.hardMode,
                          onChanged: AppSettings.instance.setHardMode,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "WORDLE" spelled in small coloured tiles.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final fills = [
      c.correct,
      c.present,
      c.absent,
      c.correct,
      c.present,
      c.correct,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 6; i++)
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fills[i],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'WORDLE'[i],
              style: TextStyle(
                color: c.onTile,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(height: 1.1),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// Today's puzzle: the main way into the game.
class _DailyCard extends StatelessWidget {
  final int number;
  final DateTime date;
  final int? length;
  final int? result;
  final bool started;
  final VoidCallback onPlay;

  const _DailyCard({
    required this.number,
    required this.date,
    required this.length,
    required this.result,
    required this.started,
    required this.onPlay,
  });

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = GameColors.of(context);
    final done = result != null;
    final won = (result ?? 0) > 0;

    final String status;
    final String button;
    final IconData icon;
    if (!done) {
      status = started ? 'In progress' : 'Ready to play';
      button = started ? 'Continue' : 'Play';
      icon = Icons.play_arrow_rounded;
    } else {
      status = won ? 'Solved in $result/6' : 'Not solved';
      button = 'See result';
      icon = Icons.leaderboard_rounded;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.10),
              scheme.primary.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'DAILY #$number',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                if (done)
                  Icon(
                    won ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: won ? colors.correct : scheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text("Today's puzzle", style: theme.textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (length != null) _EmptyTiles(count: length!),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    length == null ? '' : '$length letters · $status',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPlay,
                icon: Icon(icon),
                label: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTiles extends StatelessWidget {
  final int count;
  const _EmptyTiles({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: colors.filledBorder, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The last seven days at a glance, with a way into the full calendar.
class _WeekCard extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, int> results;
  final Set<String> playedDays;
  final VoidCallback onOpenCalendar;

  const _WeekCard({
    required this.days,
    required this.results,
    required this.playedDays,
    required this.onOpenCalendar,
  });

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final launch = dayOnly(dailyLaunch);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenCalendar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('This week', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    'Calendar',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final d in days)
                      _DayDot(
                        letter: _letters[d.weekday - 1],
                        day: d.day,
                        result: results[dateKey(d)],
                        onTheDay: playedDays.contains(dateKey(d)),
                        available: !d.isBefore(launch),
                        isToday: d == days.last,
                        colors: colors,
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
}

class _DayDot extends StatelessWidget {
  final String letter;
  final int day;
  final int? result;
  final bool onTheDay;
  final bool available;
  final bool isToday;
  final GameColors colors;

  const _DayDot({
    required this.letter,
    required this.day,
    required this.result,
    required this.onTheDay,
    required this.available,
    required this.isToday,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = result == null
        ? null
        : (result! > 0 ? colors.correct : scheme.error);

    return Column(
      children: [
        Text(
          letter,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill ?? Colors.transparent,
            border: Border.all(
              color:
                  fill ??
                  (isToday
                      ? scheme.primary
                      : available
                      ? colors.emptyBorder
                      : Colors.transparent),
              width: isToday ? 2.5 : 1.5,
            ),
          ),
          child: onTheDay
              ? Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: colors.onTile,
                )
              : Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fill != null
                        ? colors.onTile
                        : available
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final int length;
  final VoidCallback onTap;

  const _PracticeCard({required this.length, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final accent = switch (length) {
      4 => colors.correct,
      5 => colors.present,
      _ => const Color(0xFF4F5BD5),
    };
    final label = switch (length) {
      4 => 'Easy',
      5 => 'Classic',
      _ => 'Hard',
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$length',
                  style: TextStyle(
                    color: colors.onTile,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$length letters',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HardModeRow extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _HardModeRow({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        secondary: Icon(
          Icons.bolt_rounded,
          color: GameColors.of(context).present,
        ),
        title: const Text('Hard mode'),
        subtitle: Text(
          'Use every letter you find · +3 points per win',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}
