import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_logic.dart';
import '../models/game_stats.dart';

/// Everything the app saves on the device, behind one small API.
class Storage {
  Storage._();
  static final instance = Storage._();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // Points

  Future<int> points() async => (await _prefs).getInt('points_total') ?? 0;

  Future<int> addPoints(int delta) async {
    final prefs = await _prefs;
    final updated = (prefs.getInt('points_total') ?? 0) + delta;
    await prefs.setInt('points_total', updated);
    return updated;
  }

  // Stats per word length, plus one set for the Extreme levels

  Future<GameStats> stats(int length) => _stats('stats_$length');

  Future<GameStats> extremeStats() => _stats('stats_extreme');

  Future<GameStats> _stats(String key) async {
    final raw = (await _prefs).getString(key);
    if (raw == null) return GameStats();
    try {
      return GameStats.fromJson(json.decode(raw));
    } catch (_) {
      return GameStats();
    }
  }

  Future<GameStats> recordGame(
    int length, {
    required bool won,
    required int attempts,
  }) => _record('stats_$length', won: won, attempts: attempts);

  /// Extreme games keep their own stats so they don't drag down the rest.
  Future<GameStats> recordExtremeGame({
    required bool won,
    required int attempts,
  }) => _record('stats_extreme', won: won, attempts: attempts);

  Future<GameStats> _record(
    String key, {
    required bool won,
    required int attempts,
  }) async {
    final stats = await _stats(key);
    stats.record(won: won, attempts: attempts);
    await (await _prefs).setString(key, json.encode(stats.toJson()));
    return stats;
  }

  // Extreme levels

  /// The highest level cleared in a row from level 1; 0 when none.
  Future<int> extremeCleared() async =>
      (await _prefs).getInt('extreme_cleared') ?? 0;

  /// Fewest guesses each cleared level took, keyed by level number.
  Future<Map<int, int>> extremeBest() async {
    final prefs = await _prefs;
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith('extreme_best_'))
          int.parse(key.substring(13)): prefs.getInt(key)!,
    };
  }

  /// Records a cleared level and unlocks the next. Returns true the first
  /// time the level is cleared.
  Future<bool> saveExtremeWin(int level, int guesses) async {
    final prefs = await _prefs;
    final bestKey = 'extreme_best_$level';
    final best = prefs.getInt(bestKey);
    if (best == null || guesses < best) await prefs.setInt(bestKey, guesses);
    final cleared = prefs.getInt('extreme_cleared') ?? 0;
    if (level > cleared) await prefs.setInt('extreme_cleared', level);
    return best == null;
  }

  // Daily puzzles, keyed by calendar date (see dateKey)

  static const _playedDaysKey = 'daily_played_days';
  String _dailyKey(String day) => 'daily_$day';

  Future<List<String>> dailyGuesses(String day) async =>
      (await _prefs).getStringList(_dailyKey(day)) ?? [];

  Future<void> saveDailyGuesses(String day, List<String> guesses) async =>
      (await _prefs).setStringList(_dailyKey(day), guesses);

  Future<Set<int>> dailyHints(String day) async {
    final raw = (await _prefs).getStringList('${_dailyKey(day)}_hints') ?? [];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> saveDailyHints(String day, Set<int> hints) async =>
      (await _prefs).setStringList(
        '${_dailyKey(day)}_hints',
        hints.map((h) => '$h').toList(),
      );

  /// Guesses it took to solve, 0 for a loss, null if unfinished.
  Future<int?> dailyResult(String day) async =>
      (await _prefs).getInt('${_dailyKey(day)}_result');

  Future<Map<String, int>> dailyResults(Iterable<String> days) async {
    final prefs = await _prefs;
    return {
      for (final day in days)
        if (prefs.getInt('${_dailyKey(day)}_result') != null)
          day: prefs.getInt('${_dailyKey(day)}_result')!,
    };
  }

  /// Stores a finished puzzle. Only a puzzle finished on its own day counts
  /// toward the day streak, so catching up from the calendar does not.
  Future<void> saveDailyResult(String day, int result) async {
    final prefs = await _prefs;
    await prefs.setInt('${_dailyKey(day)}_result', result);
    if (day == dateKey(DateTime.now())) {
      final played = {...prefs.getStringList(_playedDaysKey) ?? <String>[]};
      played.add(day);
      await prefs.setStringList(_playedDaysKey, played.toList()..sort());
    }
  }

  Future<Set<String>> playedDays() async => {
    ...(await _prefs).getStringList(_playedDaysKey) ?? <String>[],
  };

  // Settings

  Future<bool> hardMode() async => (await _prefs).getBool('hard_mode') ?? false;

  Future<void> setHardMode(bool value) async =>
      (await _prefs).setBool('hard_mode', value);

  /// 'system', 'light' or 'dark'.
  Future<String> themeMode() async =>
      (await _prefs).getString('theme_mode') ?? 'system';

  Future<void> setThemeMode(String value) async =>
      (await _prefs).setString('theme_mode', value);

  Future<bool> seenHelp() async => (await _prefs).getBool('seen_help') ?? false;

  Future<void> setSeenHelp() async => (await _prefs).setBool('seen_help', true);
}
