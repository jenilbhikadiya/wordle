import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/storage.dart';
import '../data/word_repository.dart';
import '../models/game_stats.dart';
import 'game_logic.dart';

enum GameStatus { loading, playing, won, lost }

/// What the result sheet shows when a game ends.
class GameResult {
  final bool won;
  final GameStats stats;
  final int pointsEarned;
  final int dayStreak;
  // True when reopening a daily that was already finished.
  final bool restored;

  const GameResult({
    required this.won,
    required this.stats,
    required this.pointsEarned,
    required this.dayStreak,
    this.restored = false,
  });
}

/// Holds one game's state and rules. The screen renders it and forwards input.
class GameController extends ChangeNotifier {
  static const maxAttempts = 6;
  static const maxHints = 2;
  static const hintCost = 2;
  static const hardModeBonus = 3;
  // Time for a row of tiles to finish flipping, per tile.
  static const revealStep = Duration(milliseconds: 280);
  static const flipDuration = Duration(milliseconds: 500);

  /// The calendar day of a daily puzzle, or null for unlimited play.
  final DateTime? dailyDate;
  final int unlimitedLength;
  final bool hardMode;

  /// Called with a short message, e.g. "Not in word list".
  void Function(String message, {bool isError})? onMessage;

  /// Called when a guess is rejected, so the screen can shake the row.
  VoidCallback? onInvalid;

  /// Called once the game ends and the last row has flipped.
  void Function(GameResult result)? onFinished;

  GameController({
    this.dailyDate,
    this.unlimitedLength = 5,
    this.hardMode = false,
  });

  bool get isDaily => dailyDate != null;
  int? get dailyNo => isDaily ? dailyNumber(dailyDate!) : null;

  GameStatus status = GameStatus.loading;
  late int wordLength;
  late String target;
  Set<String> _dictionary = {};
  final List<String> guesses = [];
  String input = '';
  final Map<String, LetterState> keyStates = {};
  final Set<int> hints = {};
  GameResult? result;
  // Input is ignored while a row is flipping.
  bool _revealing = false;

  String get _dayKey => dateKey(dailyDate!);
  bool get isOver => status == GameStatus.won || status == GameStatus.lost;
  int get hintsLeft => maxHints - hints.length;
  bool get canHint => status == GameStatus.playing && hintsLeft > 0;

  Duration get rowRevealTime => revealStep * (wordLength - 1) + flipDuration;

  Future<void> start() async {
    status = GameStatus.loading;
    guesses.clear();
    keyStates.clear();
    hints.clear();
    input = '';
    result = null;
    notifyListeners();

    final words = WordRepository.instance;
    if (isDaily) {
      target = dailyWord(await words.dailySchedule(), dailyDate!);
      wordLength = target.length;
    } else {
      wordLength = unlimitedLength;
      final answers = await words.answers(wordLength);
      target = answers[math.Random().nextInt(answers.length)];
    }
    _dictionary = await words.dictionary(wordLength);

    if (isDaily) {
      for (final g in await Storage.instance.dailyGuesses(_dayKey)) {
        if (guesses.length >= maxAttempts || g.length != wordLength) break;
        guesses.add(g);
        _updateKeyStates(g);
      }
      hints.addAll(
        (await Storage.instance.dailyHints(
          _dayKey,
        )).where((i) => i >= 0 && i < wordLength),
      );
    }

    status = GameStatus.playing;
    final won = guesses.isNotEmpty && guesses.last == target;
    if (won || guesses.length >= maxAttempts) {
      status = won ? GameStatus.won : GameStatus.lost;
      result = GameResult(
        won: won,
        stats: await Storage.instance.stats(wordLength),
        pointsEarned: 0,
        dayStreak: dayStreak(
          await Storage.instance.playedDays(),
          DateTime.now(),
        ),
        restored: true,
      );
    }
    notifyListeners();
    if (result != null) onFinished?.call(result!);
  }

  void type(String letter) {
    if (status != GameStatus.playing || _revealing) return;
    if (input.length >= wordLength) return;
    input += letter.toLowerCase();
    notifyListeners();
  }

  void backspace() {
    if (status != GameStatus.playing || _revealing || input.isEmpty) return;
    input = input.substring(0, input.length - 1);
    notifyListeners();
  }

  Future<void> submit() async {
    if (status != GameStatus.playing || _revealing) return;
    final guess = input;
    if (guess.length < wordLength) return _reject('Not enough letters');
    if (!_dictionary.contains(guess)) return _reject('Not in word list');
    if (hardMode) {
      final violation = hardModeViolation(guess, guesses, target);
      if (violation != null) return _reject(violation);
    }

    _revealing = true;
    guesses.add(guess);
    input = '';
    notifyListeners();
    if (isDaily) Storage.instance.saveDailyGuesses(_dayKey, guesses);

    // Let the row flip before colouring the keyboard
    await Future.delayed(rowRevealTime);
    _updateKeyStates(guess);
    _revealing = false;

    final won = guess == target;
    if (won || guesses.length >= maxAttempts) {
      await _finish(won);
    } else {
      notifyListeners();
    }
  }

  void _reject(String message) {
    onMessage?.call(message, isError: true);
    onInvalid?.call();
  }

  Future<void> _finish(bool won) async {
    status = won ? GameStatus.won : GameStatus.lost;
    final storage = Storage.instance;
    final points = won ? _pointsForWin() : 0;
    if (points > 0) await storage.addPoints(points);
    final stats = await storage.recordGame(
      wordLength,
      won: won,
      attempts: guesses.length,
    );
    if (isDaily) {
      await storage.saveDailyResult(_dayKey, won ? guesses.length : 0);
    }
    result = GameResult(
      won: won,
      stats: stats,
      pointsEarned: points,
      dayStreak: dayStreak(await storage.playedDays(), DateTime.now()),
    );
    notifyListeners();
    onFinished?.call(result!);
  }

  int _pointsForWin() {
    const base = {4: 5, 5: 6, 6: 7};
    final bonus = hardMode ? hardModeBonus : 0;
    // Fewer guesses earn more
    final speed = maxAttempts - guesses.length;
    return math.max(
      1,
      (base[wordLength] ?? 5) + bonus + speed - hints.length * hintCost,
    );
  }

  /// Reveals one letter the player has not placed yet.
  void useHint() {
    if (!canHint) {
      if (status == GameStatus.playing) onMessage?.call('No hints left');
      return;
    }
    final placed = <int>{
      for (final g in guesses)
        for (int i = 0; i < wordLength; i++)
          if (g[i] == target[i]) i,
    };
    final open = [
      for (int i = 0; i < wordLength; i++)
        if (!placed.contains(i) && !hints.contains(i)) i,
    ];
    if (open.isEmpty) {
      onMessage?.call('Nothing left to reveal');
      return;
    }
    final pick = open[math.Random().nextInt(open.length)];
    hints.add(pick);
    if (isDaily) Storage.instance.saveDailyHints(_dayKey, hints);
    onMessage?.call(
      '${ordinal(pick + 1)} letter is ${target[pick].toUpperCase()} '
      '(−$hintCost points)',
    );
    notifyListeners();
  }

  void _updateKeyStates(String guess) {
    final states = scoreGuess(guess, target);
    for (int i = 0; i < guess.length; i++) {
      final current = keyStates[guess[i]];
      final next = states[i];
      // A key only ever upgrades: absent < present < correct
      if (current == null || next.index < current.index) {
        keyStates[guess[i]] = next;
      }
    }
  }

  String share() => shareText(
    guesses: guesses,
    target: target,
    wordLength: wordLength,
    maxAttempts: maxAttempts,
    won: status == GameStatus.won,
    hardMode: hardMode,
    hintsUsed: hints.length,
    dailyDate: dailyDate,
  );
}
