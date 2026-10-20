import 'package:flutter/material.dart';

import '../utils/game_logic.dart';
import '../utils/stats_service.dart';
import 'game_screen.dart';

/// Month view of every daily puzzle. Past days can be opened (to play a missed
/// day or review a finished one); future days stay locked until they arrive.
class CalendarScreen extends StatefulWidget {
  final bool hardMode;
  const CalendarScreen({super.key, this.hardMode = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const accent = Color(0xFF0ff4c6);
  static const win = Color(0xFF2ecc71);
  static const loss = Color(0xFFff006e);
  static const streakColor = Color(0xFFff9f1c);
  static const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY',
    'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
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
    final now = DateTime.now();
    final days = <String>[];
    // Every day from launch to today, so the totals cover all months
    for (var d = dayOnly(dailyLaunch);
        !d.isAfter(dayOnly(now));
        d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(dateKey(d));
    }
    final results = await DailyService.getResults(days);
    final played = await DailyService.getPlayedDays();
    if (!mounted) return;
    setState(() {
      _results = results;
      _playedDays = played;
    });
  }

  bool get _canGoBack {
    final launch = DateTime(dailyLaunch.year, dailyLaunch.month);
    return _month.isAfter(launch);
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _openDay(DateTime day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(dailyDate: day, hardMode: widget.hardMode),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final wins = _results.values.where((r) => r > 0).length;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0f0f1e), Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: accent),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CALENDAR',
                        style: TextStyle(
                          color: accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: accent.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Total(
                        icon: Icons.local_fire_department,
                        value: '${dayStreak(_playedDays, now)}',
                        label: 'DAY STREAK',
                        color: streakColor,
                      ),
                      _Total(
                        icon: Icons.emoji_events,
                        value: '${bestDayStreak(_playedDays)}',
                        label: 'BEST STREAK',
                        color: streakColor,
                      ),
                      _Total(
                        icon: Icons.check_circle,
                        value: '$wins/${_results.length}',
                        label: 'SOLVED',
                        color: accent,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: accent.withOpacity(_canGoBack ? 1 : 0.2)),
                        onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
                      ),
                      Expanded(
                        child: Text(
                          '${months[_month.month - 1]} ${_month.year}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                            color:
                                accent.withOpacity(_canGoForward ? 1 : 0.2)),
                        onPressed:
                            _canGoForward ? () => _shiftMonth(1) : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildGrid(now),
                  SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Legend(color: win, label: 'Solved'),
                      _Legend(color: loss, label: 'Missed'),
                      _Legend(color: accent, label: 'Open', outlined: true),
                      _Legend(
                          icon: Icons.local_fire_department,
                          color: streakColor,
                          label: 'Played on the day'),
                      _Legend(
                          icon: Icons.lock,
                          color: Colors.white38,
                          label: 'Locked'),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Catching up on a past day adds to your stats, but only '
                    'playing on the day keeps your streak going.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(DateTime now) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1; // Monday first
    final cells = <Widget>[
      for (final w in weekdays)
        Center(
          child: Text(
            w,
            style: TextStyle(
              color: accent.withOpacity(0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      for (int i = 0; i < leading; i++) SizedBox.shrink(),
      for (int d = 1; d <= daysInMonth; d++)
        _buildDay(DateTime(_month.year, _month.month, d), now),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }

  Widget _buildDay(DateTime day, DateTime now) {
    final key = dateKey(day);
    final isToday = key == dateKey(now);
    final beforeLaunch = day.isBefore(dayOnly(dailyLaunch));
    final unlocked = isDailyUnlocked(day, now);
    final result = _results[key];

    if (beforeLaunch) {
      return Center(
        child: Text(
          '${day.day}',
          style: TextStyle(color: Colors.white12),
        ),
      );
    }

    if (!unlocked) {
      return Tooltip(
        message: 'Unlocks on this day',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.03),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.day}', style: TextStyle(color: Colors.white24)),
              Icon(Icons.lock, size: 12, color: Colors.white24),
            ],
          ),
        ),
      );
    }

    final Color? fill = result == null ? null : (result > 0 ? win : loss);
    return GestureDetector(
      onTap: () => _openDay(day),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: fill?.withOpacity(0.8) ?? Colors.transparent,
          border: Border.all(
            color: isToday ? Colors.white : (fill ?? accent.withOpacity(0.5)),
            width: isToday ? 2.5 : 1.5,
          ),
          boxShadow: isToday
              ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: fill == null ? accent : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (result != null)
                    Text(
                      result > 0 ? '$result/6' : 'X',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            if (_playedDays.contains(key))
              Positioned(
                top: 1,
                right: 1,
                child: Icon(
                  Icons.local_fire_department,
                  size: 12,
                  color: streakColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Total({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
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
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
