import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';

class GameStats {
  int played;
  int wins;
  int currentStreak;
  int maxStreak;
  // distribution[i] is the number of wins that took i + 1 guesses.
  List<int> distribution;

  GameStats({
    this.played = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    List<int>? distribution,
  }) : distribution = distribution ?? List<int>.filled(6, 0);

  int get winPercent => played == 0 ? 0 : (wins * 100 / played).round();

  void record({required bool won, required int attempts}) {
    played++;
    if (won) {
      wins++;
      currentStreak++;
      if (currentStreak > maxStreak) maxStreak = currentStreak;
      if (attempts >= 1 && attempts <= distribution.length) {
        distribution[attempts - 1]++;
      }
    } else {
      currentStreak = 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'played': played,
        'wins': wins,
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
        'distribution': distribution,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) {
    final dist = (json['distribution'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        <int>[];
    return GameStats(
      played: json['played'] ?? 0,
      wins: json['wins'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      maxStreak: json['maxStreak'] ?? 0,
      distribution: List<int>.generate(6, (i) => i < dist.length ? dist[i] : 0),
    );
  }
}

class StatsService {
  static String _key(int length) => 'stats_$length';

  static Future<GameStats> getStats(int length) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(length));
    if (raw == null) return GameStats();
    try {
      return GameStats.fromJson(json.decode(raw));
    } catch (_) {
      return GameStats();
    }
  }

  static Future<GameStats> recordGame(int length,
      {required bool won, required int attempts}) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getStats(length);
    stats.record(won: won, attempts: attempts);
    await prefs.setString(_key(length), json.encode(stats.toJson()));
    return stats;
  }
}

/// Saves the guesses made on each daily puzzle so it can only be played once,
/// and so a half-finished daily is restored when reopened. Puzzles are keyed
/// by their calendar date (see dateKey).
class DailyService {
  static const String _playedDaysKey = 'daily_played_days';
  static String _key(String day) => 'daily_$day';

  static Future<List<String>> getGuesses(String day) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(day)) ?? [];
  }

  static Future<void> saveGuesses(String day, List<String> guesses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(day), guesses);
  }

  static Future<List<int>> getHints(String day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('${_key(day)}_hints') ?? [];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  static Future<void> saveHints(String day, Set<int> hints) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        '${_key(day)}_hints', hints.map((h) => '$h').toList());
  }

  /// Number of guesses it took to solve, 0 for a loss, null if unfinished.
  static Future<int?> getResult(String day) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_key(day)}_result');
  }

  /// Results for many days at once, for the calendar.
  static Future<Map<String, int>> getResults(Iterable<String> days) async {
    final prefs = await SharedPreferences.getInstance();
    final results = <String, int>{};
    for (final day in days) {
      final r = prefs.getInt('${_key(day)}_result');
      if (r != null) results[day] = r;
    }
    return results;
  }

  /// Stores a finished puzzle. Only a puzzle finished on its own day counts
  /// toward the day streak, so catching up from the calendar does not.
  static Future<void> saveResult(String day, int result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_key(day)}_result', result);
    if (day == dateKey(DateTime.now())) {
      final played = {...prefs.getStringList(_playedDaysKey) ?? <String>[]};
      played.add(day);
      await prefs.setStringList(_playedDaysKey, played.toList()..sort());
    }
  }

  static Future<Set<String>> getPlayedDays() async {
    final prefs = await SharedPreferences.getInstance();
    return {...prefs.getStringList(_playedDaysKey) ?? <String>[]};
  }

  static Future<int> currentDayStreak(DateTime now) async =>
      dayStreak(await getPlayedDays(), now);
}

class SettingsService {
  static const String _hardModeKey = 'hard_mode';

  static Future<bool> getHardMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hardModeKey) ?? false;
  }

  static Future<void> setHardMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hardModeKey, value);
  }
}
