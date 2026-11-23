import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_wordle/data/storage.dart';
import 'package:flutter_wordle/data/word_repository.dart';
import 'package:flutter_wordle/game/extreme_levels.dart';
import 'package:flutter_wordle/game/game_controller.dart';

void enter(GameController game, String word) {
  for (final c in word.split('')) {
    game.type(c);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('level list', () {
    test('has 50 numbered levels, ten per tier, no repeated word', () {
      expect(extremeLevels, hasLength(50));
      for (int i = 0; i < extremeLevels.length; i++) {
        final level = extremeLevels[i];
        expect(level.number, i + 1);
        expect(level.tier.index, i ~/ 10);
        expect(level.word, matches(RegExp(r'^[a-z]{4,6}$')));
      }
      expect(extremeLevels.map((l) => l.word).toSet(), hasLength(50));
    });

    test('rules tighten tier by tier', () {
      final first = extremeLevels.first;
      final last = extremeLevels.last;
      expect(first.maxAttempts, 5);
      expect(first.hints, 1);
      expect(first.blindKeyboard, isFalse);
      expect(extremeLevels[10].hints, 0);
      expect(extremeLevels[30].blindKeyboard, isTrue);
      expect(last.maxAttempts, 4);
      expect(last.blindKeyboard, isTrue);
    });

    test('every word is accepted as a guess', () async {
      for (final level in extremeLevels) {
        final dict = await WordRepository.instance.dictionary(level.wordLength);
        expect(dict, contains(level.word), reason: level.word);
      }
    });

    test('only the next level after the last cleared is unlocked', () {
      expect(isExtremeUnlocked(1, 0), isTrue);
      expect(isExtremeUnlocked(2, 0), isFalse);
      expect(isExtremeUnlocked(13, 12), isTrue);
      expect(isExtremeUnlocked(14, 12), isFalse);
      expect(isExtremeUnlocked(51, 50), isFalse);
    });
  });

  group('playing a level', () {
    test('uses the level word, its guess limit and forced hard mode', () async {
      final level = extremeLevels[40];
      final game = GameController(level: level);
      await game.start();
      expect(game.target, level.word);
      expect(game.maxAttempts, 4);
      expect(game.hardMode, isTrue);
      expect(game.hintLimit, 0);
      expect(game.canHint, isFalse);
      expect(game.showKeyColors, isFalse);
    });

    test('hard mode rules apply', () async {
      final game = GameController(level: extremeLevels[30]); // hound
      await game.start();
      final messages = <String>[];
      game.onMessage = (m, {isError = false}) => messages.add(m);
      enter(game, 'round');
      await game.submit();
      enter(game, 'crane');
      await game.submit();
      expect(messages.single, startsWith('2nd letter must be O'));
      expect(game.guesses, ['round']);
    });

    test('a win unlocks the next level and pays points once', () async {
      final level = extremeLevels.first;
      GameResult? result;
      final game = GameController(level: level)..onFinished = (r) => result = r;
      await game.start();
      enter(game, level.word);
      await game.submit();

      expect(result?.won, isTrue);
      expect(result?.levelCleared, isTrue);
      expect(result?.pointsEarned, level.pointsFor(1));
      expect(await Storage.instance.extremeCleared(), 1);
      expect(await Storage.instance.extremeBest(), {1: 1});
      expect((await Storage.instance.extremeStats()).wins, 1);
      expect((await Storage.instance.stats(level.wordLength)).played, 0);

      final replay = GameController(level: level)
        ..onFinished = (r) => result = r;
      await replay.start();
      enter(replay, level.word);
      await replay.submit();
      expect(result?.levelCleared, isFalse);
      expect(result?.pointsEarned, 0);
    });

    test('running out of guesses loses without unlocking', () async {
      final level = extremeLevels.last; // zigzag, 4 guesses
      final game = GameController(level: level);
      await game.start();
      expect(game.wordLength, 6);
      final dict = (await WordRepository.instance.dictionary(
        6,
      )).where((w) => w != level.word).toList();
      // Hard mode needs later guesses to reuse found letters, so pick guesses
      // that share nothing with the target.
      final misses = dict
          .where((w) => !w.split('').any(level.word.contains))
          .take(4)
          .toList();
      for (final w in misses) {
        enter(game, w);
        await game.submit();
      }
      expect(game.status, GameStatus.lost);
      expect(await Storage.instance.extremeCleared(), 0);
    });

    test('share text names the level', () async {
      final game = GameController(level: extremeLevels[9]);
      await game.start();
      enter(game, game.target);
      await game.submit();
      expect(game.share(), startsWith('Wordle Future · Extreme 10 '));
      expect(game.share(), contains('1/5*'));
    });
  });
}
