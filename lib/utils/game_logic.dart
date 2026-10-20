// Pure game rules, kept free of Flutter so they are easy to unit test.

enum LetterState { correct, present, absent }

/// Scores [guess] against [target] using standard Wordle rules, so a repeated
/// letter is only marked present as many times as it appears in the target.
List<LetterState> scoreGuess(String guess, String target) {
  final result = List<LetterState>.filled(guess.length, LetterState.absent);
  final remaining = target.split('');

  for (int i = 0; i < guess.length; i++) {
    if (guess[i] == remaining[i]) {
      result[i] = LetterState.correct;
      remaining[i] = '';
    }
  }
  for (int i = 0; i < guess.length; i++) {
    if (result[i] == LetterState.correct) continue;
    final idx = remaining.indexOf(guess[i]);
    if (idx != -1) {
      result[i] = LetterState.present;
      remaining[idx] = '';
    }
  }
  return result;
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

/// Hard mode: every revealed hint must be used in later guesses. Returns a
/// message describing the first broken rule, or null if [guess] is allowed.
String? hardModeViolation(
    String guess, List<String> previousGuesses, String target) {
  for (final prev in previousGuesses) {
    final states = scoreGuess(prev, target);

    for (int i = 0; i < prev.length; i++) {
      if (states[i] == LetterState.correct && guess[i] != prev[i]) {
        return '${ordinal(i + 1)} letter must be ${prev[i].toUpperCase()}';
      }
    }

    final required = <String, int>{};
    for (int i = 0; i < prev.length; i++) {
      if (states[i] != LetterState.absent) {
        required[prev[i]] = (required[prev[i]] ?? 0) + 1;
      }
    }
    for (final entry in required.entries) {
      final count = guess.split('').where((c) => c == entry.key).length;
      if (count < entry.value) {
        return 'Guess must contain ${entry.key.toUpperCase()}';
      }
    }
  }
  return null;
}

/// Calendar date as yyyy-mm-dd, used to key daily puzzles.
String dateKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// The first day a daily puzzle exists; puzzle #1.
final DateTime dailyLaunch = DateTime(2026, 10, 20);

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Puzzle number for a calendar date, counting from [dailyLaunch] as #1.
int dailyNumber(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final launch =
      DateTime.utc(dailyLaunch.year, dailyLaunch.month, dailyLaunch.day);
  return day.difference(launch).inDays + 1;
}

/// The word for a calendar date. The daily list is already shuffled and has
/// no repeats, so each day gets a unique word until the list runs out.
String dailyWord(List<String> words, DateTime date) {
  final index = (dailyNumber(date) - 1) % words.length;
  return words[index < 0 ? index + words.length : index];
}

/// Whether the daily puzzle for [date] can be played: from launch up to today,
/// never a future day.
bool isDailyUnlocked(DateTime date, DateTime now) {
  final day = dayOnly(date);
  return !day.isBefore(dayOnly(dailyLaunch)) && !day.isAfter(dayOnly(now));
}

/// Counts consecutive days ending today (or yesterday, if today's puzzle is
/// not played yet) found in [playedDays], a set of [dateKey]s.
int dayStreak(Set<String> playedDays, DateTime now) {
  var day = dayOnly(now);
  if (!playedDays.contains(dateKey(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (playedDays.contains(dateKey(day))) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Longest run of consecutive days in [playedDays].
int bestDayStreak(Set<String> playedDays) {
  final days = playedDays.map(DateTime.parse).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    final next = prev == null ? null : DateTime(prev.year, prev.month, prev.day + 1);
    run = (next != null && dateKey(next) == dateKey(d)) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// Emoji summary of a finished game, ready to paste into a chat.
String shareText({
  required List<String> guesses,
  required String target,
  required int wordLength,
  required int maxAttempts,
  required bool won,
  required bool hardMode,
  int hintsUsed = 0,
  DateTime? dailyDate,
}) {
  final title = dailyDate != null
      ? 'Wordle Future #${dailyNumber(dailyDate)}'
      : 'Wordle Future';
  final score = '${won ? guesses.length : 'X'}/$maxAttempts${hardMode ? '*' : ''}';
  final hints = hintsUsed > 0
      ? ' · $hintsUsed hint${hintsUsed == 1 ? '' : 's'}'
      : '';

  final rows = guesses.map((g) {
    return scoreGuess(g, target).map((s) {
      switch (s) {
        case LetterState.correct:
          return '🟩';
        case LetterState.present:
          return '🟨';
        case LetterState.absent:
          return '⬛';
      }
    }).join();
  }).join('\n');

  return '$title · $wordLength letters · $score$hints\n\n$rows';
}
