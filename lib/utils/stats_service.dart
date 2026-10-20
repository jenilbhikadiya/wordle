import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Saves the guesses made on each daily puzzle so it can only be played once
/// a day, and so a half-finished daily is restored when reopened.
class DailyService {
  static String _key(int length, String date) => 'daily_${length}_$date';

  static Future<List<String>> getGuesses(int length, String date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(length, date)) ?? [];
  }

  static Future<void> saveGuesses(
      int length, String date, List<String> guesses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(length, date), guesses);
  }

  static Future<List<int>> getHints(int length, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('${_key(length, date)}_hints') ?? [];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  static Future<void> saveHints(int length, String date, Set<int> hints) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        '${_key(length, date)}_hints', hints.map((h) => '$h').toList());
  }

  /// Number of guesses it took to solve, 0 for a loss, null if unfinished.
  static Future<int?> getResult(int length, String date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_key(length, date)}_result');
  }

  static Future<void> saveResult(int length, String date, int result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_key(length, date)}_result', result);
  }
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
