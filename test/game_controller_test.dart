import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_wordle/data/storage.dart';
import 'package:flutter_wordle/data/word_repository.dart';
import 'package:flutter_wordle/game/game_controller.dart';
import 'package:flutter_wordle/game/game_logic.dart';

Future<GameController> startedGame({DateTime? daily, bool hard = false}) async {
  final game = GameController(dailyDate: daily, hardMode: hard);
  await game.start();
  return game;
}

void enter(GameController game, String word) {
  for (final c in word.split('')) {
    game.type(c);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rejects short and unknown words without using a row', () async {
    final game = await startedGame();
    final messages = <String>[];
    game.onMessage = (m, {isError = false}) => messages.add(m);

    enter(game, 'cra');
    await game.submit();
    game
      ..backspace()
      ..backspace()
      ..backspace();
    enter(game, 'zzzzz');
    await game.submit();

    expect(messages, ['Not enough letters', 'Not in word list']);
    expect(game.guesses, isEmpty);
  });

  test('a daily game uses the scheduled word and records the win', () async {
    final day = DateTime(2026, 10, 20);
    final game = await startedGame(daily: day);
    final expected =
        dailyWord(await WordRepository.instance.dailySchedule(), day);
    expect(game.target, expected);
    expect(game.wordLength, expected.length);

    GameResult? result;
    game.onFinished = (r) => result = r;
    enter(game, expected);
    await game.submit();

    expect(game.status, GameStatus.won);
    expect(result?.won, isTrue);
    expect(result?.pointsEarned, greaterThan(0));
    expect(await Storage.instance.dailyResult(dateKey(day)), 1);
    expect((await Storage.instance.stats(expected.length)).wins, 1);
    for (final c in expected.split('')) {
      expect(game.keyStates[c], LetterState.correct);
    }
  });

  test('reopening a finished daily restores it instead of replaying', () async {
    final day = DateTime(2026, 10, 21);
    final first = await startedGame(daily: day);
    enter(first, first.target);
    await first.submit();

    final again = await startedGame(daily: day);
    expect(again.status, GameStatus.won);
    expect(again.guesses, [first.target]);
    expect(again.result?.restored, isTrue);
  });

  test('a hint reveals an unplaced letter and is limited', () async {
    final game = await startedGame();
    game.useHint();
    game.useHint();
    game.useHint();
    expect(game.hints.length, GameController.maxHints);
    expect(game.hintsLeft, 0);
  });
}
