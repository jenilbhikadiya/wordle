import 'package:flutter/material.dart';

import '../data/storage.dart';
import '../game/game_logic.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

/// Month view of every daily puzzle. Past days can be opened to catch up or
/// review; future days stay locked until they arrive.
class CalendarScreen extends StatefulWidget {
  final bool hardMode;
  const CalendarScreen({super.key, this.hardMode = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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

  late DateTime _month;
  Map<String, int> _results = {};
  Set<String> _playedDays = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    final now = dayOnly(DateTime.now());
    final days = [
      for (
        var d = dayOnly(dailyLaunch);
        !d.isAfter(now);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        dateKey(d),
    ];
    final results = await Storage.instance.dailyResults(days);
    final played = await Storage.instance.playedDays();
    if (!mounted) return;
    setState(() {
      _results = results;
      _playedDays = played;
    });
  }

  bool get _canGoBack =>
      _month.isAfter(DateTime(dailyLaunch.year, dailyLaunch.month));

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  Future<void> _openDay(DateTime day) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(dailyDate: day, hardMode: widget.hardMode),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final now = DateTime.now();
    final wins = _results.values.where((r) => r > 0).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    _Summary(
                      icon: Icons.local_fire_department_rounded,
                      color: colors.streak,
                      value: '${dayStreak(_playedDays, now)}',
                      label: 'Day streak',
                    ),
                    const SizedBox(width: 12),
                    _Summary(
                      icon: Icons.emoji_events_rounded,
                      color: colors.present,
                      value: '${bestDayStreak(_playedDays)}',
                      label: 'Best streak',
                    ),
                    const SizedBox(width: 12),
                    _Summary(
                      icon: Icons.check_circle_rounded,
                      color: colors.correct,
                      value: '$wins',
                      label: 'Solved',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous month',
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: _canGoBack
                                  ? () => setState(
                                      () => _month = DateTime(
                                        _month.year,
                                        _month.month - 1,
                                      ),
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                '${_months[_month.month - 1]} ${_month.year}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next month',
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _canGoForward
                                  ? () => setState(
                                      () => _month = DateTime(
                                        _month.year,
                                        _month.month + 1,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildGrid(context, now),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Legend(color: colors.correct, label: 'Solved'),
                    _Legend(
                      color: theme.colorScheme.error,
                      label: 'Not solved',
                    ),
                    _Legend(
                      color: theme.colorScheme.primary,
                      label: 'Open',
                      outlined: true,
                    ),
                    _Legend(
                      icon: Icons.local_fire_department_rounded,
                      color: colors.streak,
                      label: 'Played on the day',
                    ),
                    _Legend(
                      icon: Icons.lock_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      label: 'Locked',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Catching up on a past day counts in your stats. Only playing '
                  'on the day keeps your streak going.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1; // Monday first
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final w in _weekdays)
          Center(
            child: Text(
              w,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        for (int i = 0; i < leading; i++) const SizedBox.shrink(),
        for (int d = 1; d <= daysInMonth; d++)
          _buildDay(context, DateTime(_month.year, _month.month, d), now),
      ],
    );
  }

  Widget _buildDay(BuildContext context, DateTime day, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = GameColors.of(context);
    final key = dateKey(day);
    final isToday = key == dateKey(now);
    final result = _results[key];

    if (day.isBefore(dayOnly(dailyLaunch))) {
      return Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (!isDailyUnlocked(day, now)) {
      return Tooltip(
        message: 'Unlocks on this day',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.surfaceContainer,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.lock_rounded,
                size: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    final fill = result == null
        ? null
        : (result > 0 ? colors.correct : scheme.error);
    return Material(
      color: fill ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isToday
              ? scheme.primary
              : (fill ?? scheme.primary.withValues(alpha: 0.35)),
          width: isToday ? 2.5 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDay(day),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: fill == null ? scheme.onSurface : colors.onTile,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (result != null)
                    Text(
                      result > 0 ? '$result/6' : '✕',
                      style: TextStyle(
                        color: colors.onTile,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (_playedDays.contains(key))
              Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: fill != null ? colors.onTile : colors.streak,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _Summary({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleLarge),
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

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool outlined;

  const _Legend({
    required this.color,
    required this.label,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon != null
            ? Icon(icon, size: 14, color: color)
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: outlined ? Colors.transparent : color,
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
