import 'package:flutter/material.dart';

import '../game/game_logic.dart';
import '../theme/app_theme.dart';

/// On-screen QWERTY keyboard coloured with what each letter is known to be.
class GameKeyboard extends StatelessWidget {
  final Map<String, LetterState> keyStates;
  final ValueChanged<String> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;

  const GameKeyboard({
    super.key,
    required this.keyStates,
    required this.onLetter,
    required this.onEnter,
    required this.onBackspace,
  });

  static const _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(context, _rows[0].split('')),
          Padding(
            // The middle row is inset by half a key, like a real keyboard
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _row(context, _rows[1].split('')),
          ),
          Row(
            children: [
              _Key(
                flex: 3,
                onTap: onEnter,
                semanticLabel: 'Enter',
                child: const Text(
                  'ENTER',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              for (final k in _rows[2].split('')) _letterKey(context, k),
              _Key(
                flex: 3,
                onTap: onBackspace,
                semanticLabel: 'Backspace',
                child: const Icon(Icons.backspace_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, List<String> keys) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [for (final k in keys) _letterKey(context, k)]),
  );

  Widget _letterKey(BuildContext context, String k) {
    final colors = GameColors.of(context);
    final state = keyStates[k];
    final bg = switch (state) {
      LetterState.correct => colors.correct,
      LetterState.present => colors.present,
      LetterState.absent => colors.absent,
      null => null,
    };
    return _Key(
      flex: 2,
      background: bg,
      foreground: bg == null ? null : colors.onTile,
      onTap: () => onLetter(k),
      semanticLabel: k,
      child: Text(
        k.toUpperCase(),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final int flex;
  final Widget child;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final String semanticLabel;

  const _Key({
    required this.flex,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: background ?? colors.key,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: foreground ?? colors.onKey),
                    child: IconTheme.merge(
                      data: IconThemeData(color: foreground ?? colors.onKey),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
