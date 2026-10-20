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

/// Days since the first daily puzzle, counted on the local calendar date.
int dailyNumber(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return day.difference(DateTime.utc(2025, 1, 1)).inDays + 1;
}

/// Picks the same word for everyone on a given day. The word lists are
/// alphabetical, so the day number is scrambled before indexing.
String dailyWord(List<String> words, int length, DateTime date) {
  final n = dailyNumber(date);
  final index = (n * 7919 + length * 104729) % words.length;
  return words[index.abs()];
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
