import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/board.dart';
import '../widgets/info_sheets.dart';
import '../widgets/keyboard.dart';
import '../widgets/result_sheet.dart';

class GameScreen extends StatefulWidget {
  /// The calendar day of a daily puzzle, or null for practice.
  final DateTime? dailyDate;
  final int wordLength;
  final bool hardMode;

  const GameScreen({
    super.key,
    this.dailyDate,
    this.wordLength = 5,
    this.hardMode = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _game = GameController(
    dailyDate: widget.dailyDate,
    unlimitedLength: widget.wordLength,
    hardMode: widget.hardMode,
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  final _focus = FocusNode();
  String? _toast;
  bool _toastIsError = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _game
      ..onMessage = _showToast
      ..onInvalid = _shakeRow
        ..onFinished = _onFinished
        ..start();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _shake.dispose();
    _focus.dispose();
    _game.dispose();
    super.dispose();
  }

  void _shakeRow() => _shake.forward(from: 0);

  void _showToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toast = message;
      _toastIsError = isError;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _onFinished(GameResult result) async {
    // A finished game shows the result after the winning bounce plays
    if (!result.restored) {
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (!result.won && !result.restored) {
      _showToast(_game.target.toUpperCase());
    }
    if (!mounted) return;
    await _openResult();
  }

  Future<void> _openResult() async {
    final result = _game.result;
    if (result == null) return;
    final action = await showResultSheet(context, _game, result);
    if (!mounted) return;
    if (action == ResultAction.playAgain) {
      _game.start();
    } else if (action == ResultAction.close) {
      Navigator.pop(context);
    }
  }

  // Physical keyboard support for web and desktop
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _game.submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _game.backspace();
      return KeyEventResult.handled;
    }
    final ch = event.character?.toLowerCase();
    if (ch != null && RegExp(r'^[a-z]$').hasMatch(ch)) {
      _game.type(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final loading = _game.status == GameStatus.loading;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(_game.isDaily ? 'Daily #${_game.dailyNo}' : 'Practice'),
                if (!loading)
                  Text(
                    '${_game.wordLength} letters'
                    '${_game.hardMode ? ' · Hard mode' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
            actions: [
              if (!loading && !_game.isOver)
                _HintButton(
                  hintsLeft: _game.hintsLeft,
                  onPressed: _game.useHint,
                ),
              if (_game.isOver)
                IconButton(
                  tooltip: 'Results',
                  icon: const Icon(Icons.leaderboard_rounded),
                  onPressed: _openResult,
                ),
              IconButton(
                tooltip: 'How to play',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () => showHelpSheet(context),
              ),
            ],
          ),
          body: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: SafeArea(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  12,
                                ),
                                child: Board(game: _game, shake: _shake),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                              child: GameKeyboard(
                                keyStates: _game.keyStates,
                                onLetter: _game.type,
                                onEnter: _game.submit,
                                onBackspace: _game.backspace,
                              ),
                            ),
                          ],
                        ),
                        _Toast(message: _toast, isError: _toastIsError),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _HintButton extends StatelessWidget {
  final int hintsLeft;
  final VoidCallback onPressed;

  const _HintButton({required this.hintsLeft, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return IconButton(
      tooltip: 'Reveal a letter ($hintsLeft left)',
      onPressed: onPressed,
      icon: Badge(
        label: Text('$hintsLeft'),
        backgroundColor: hintsLeft > 0 ? colors.hint : colors.absent,
        textColor: Colors.black87,
        child: Icon(
          Icons.lightbulb_outline_rounded,
          color: hintsLeft > 0 ? null : colors.absent,
        ),
      ),
    );
  }
}

/// Short message that drops in over the top of the board.
class _Toast extends StatelessWidget {
  final String? message;
  final bool isError;

  const _Toast({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: message == null
              ? const SizedBox.shrink()
              : Center(
                  key: ValueKey(message),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isError ? scheme.error : scheme.onSurface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12),
                      ],
                    ),
                    child: Text(
                      message!,
                      style: TextStyle(
                        color: isError ? scheme.onError : scheme.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
