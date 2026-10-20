import 'dart:convert';
import 'dart:io';

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

  group('daily puzzles', () {
    final launch = DateTime(2026, 10, 20);
    final words = List.generate(2000, (i) => 'w$i');

    test('the launch day is puzzle #1 and each day gets a new word', () {
      expect(dailyNumber(launch), 1);
      expect(dailyWord(words, launch), 'w0');
      expect(dailyWord(words, DateTime(2026, 10, 21, 23, 59)), 'w1');
      final seen = {
        for (int i = 0; i < 2000; i++)
          dailyWord(words, DateTime(2026, 10, 20 + i)),
      };
      expect(seen.length, 2000);
    });

    test('the schedule loops back to day 1 after the last day', () {
      final last = DateTime(2026, 10, 20 + 1999);
      expect(dailyWord(words, last), 'w1999');
      expect(dailyWord(words, DateTime(2026, 10, 20 + 2000)), 'w0');
      expect(dailyWord(words, DateTime(2026, 10, 20 + 2001)), 'w1');
    });

    test('the daily schedule dates 2000 unique 4-6 letter words', () {
      final entries = (json.decode(
              File('assets/daily_words.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(entries.length, 2000);
      final words = entries.map((e) => e['word'] as String).toList();
      expect(words.toSet().length, 2000);
      expect(words.every((w) => RegExp(r'^[a-z]{4,6}$').hasMatch(w)), isTrue);
      expect(words.map((w) => w.length).toSet(), {4, 5, 6});
      for (int i = 0; i < entries.length; i++) {
        final date = DateTime.parse(entries[i]['date']);
        expect(entries[i]['day'], i + 1);
        expect(dailyNumber(date), i + 1, reason: entries[i]['date']);
        expect(dailyWord(words, date), words[i]);
      }
    });

    test('future days stay locked', () {
      final now = DateTime(2026, 11, 3, 9);
      expect(isDailyUnlocked(DateTime(2026, 11, 3), now), isTrue);
      expect(isDailyUnlocked(DateTime(2026, 10, 25), now), isTrue);
      expect(isDailyUnlocked(DateTime(2026, 11, 4), now), isFalse);
      expect(isDailyUnlocked(DateTime(2026, 10, 19), now), isFalse);
    });

    test('day streak counts consecutive played days', () {
      final played = {'2026-10-28', '2026-10-30', '2026-10-31', '2026-11-01'};
      // Today not played yet: the streak through yesterday still stands
      expect(dayStreak(played, DateTime(2026, 11, 2, 8)), 3);
      expect(dayStreak({...played, '2026-11-02'}, DateTime(2026, 11, 2)), 4);
      // Missing yesterday and today breaks it
      expect(dayStreak(played, DateTime(2026, 11, 3)), 0);
      expect(bestDayStreak(played), 3);
      expect(bestDayStreak({}), 0);
    });
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
