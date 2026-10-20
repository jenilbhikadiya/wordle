import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_wordle/utils/game_logic.dart';
import 'package:flutter_wordle/utils/stats_service.dart';

const c = LetterState.correct;
const p = LetterState.present;
const a = LetterState.absent;

void main() {
  group('scoreGuess', () {
    test('marks correct, present and absent letters', () {
      expect(scoreGuess('crane', 'react'), [p, p, c, a, p]);
    });

    test('does not over-count repeated letters', () {
      expect(scoreGuess('speed', 'abide'), [a, a, p, a, p]);
      expect(scoreGuess('eerie', 'there'), [p, a, p, a, c]);
    });
  });

  group('hardModeViolation', () {
    test('requires green letters to stay in place', () {
      expect(hardModeViolation('trace', ['crane'], 'crate'),
          '1st letter must be C');
    });

    test('requires yellow letters to be reused', () {
      expect(hardModeViolation('scary', ['crane'], 'react'),
          'Guess must contain E');
    });

    test('allows a guess that uses every hint', () {
      expect(hardModeViolation('react', ['crane'], 'react'), isNull);
    });
  });

  test('dailyWord is stable for a date and changes day to day', () {
    final words = List.generate(500, (i) => 'w$i');
    final day = DateTime(2026, 10, 20);
    expect(dailyWord(words, 5, day), dailyWord(words, 5, day));
    expect(dailyWord(words, 5, day),
        isNot(dailyWord(words, 5, day.add(Duration(days: 1)))));
  });

  test('shareText renders an emoji grid', () {
    final text = shareText(
      guesses: ['crane', 'react'],
      target: 'react',
      wordLength: 5,
      maxAttempts: 6,
      won: true,
      hardMode: true,
    );
    expect(text, contains('2/6*'));
    expect(text, endsWith('🟨🟨🟩⬛🟨\n🟩🟩🟩🟩🟩'));
  });

  test('GameStats tracks streaks and distribution', () {
    final stats = GameStats()
      ..record(won: true, attempts: 3)
      ..record(won: true, attempts: 4)
      ..record(won: false, attempts: 6)
      ..record(won: true, attempts: 3);
    expect(stats.played, 4);
    expect(stats.winPercent, 75);
    expect(stats.currentStreak, 1);
    expect(stats.maxStreak, 2);
    expect(stats.distribution, [0, 0, 2, 1, 0, 0]);
    expect(GameStats.fromJson(stats.toJson()).toJson(), stats.toJson());
  });
}
