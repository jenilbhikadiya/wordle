import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/game_logic.dart';
import '../theme/app_theme.dart';

/// The grid of guesses. Sizes its tiles to fit the space it is given.
class Board extends StatelessWidget {
  final GameController game;
  final Animation<double> shake;

  const Board({super.key, required this.game, required this.shake});

  @override
  Widget build(BuildContext context) {
    final length = game.wordLength;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final byWidth = (constraints.maxWidth - gap * (length - 1)) / length;
        final byHeight = (constraints.maxHeight - gap * 5) / 6;
        final size = math
            .min(66.0, math.min(byWidth, byHeight))
            .floorToDouble();

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int r = 0; r < GameController.maxAttempts; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r == 5 ? 0 : gap),
                  child: _buildRow(r, size, gap),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(int r, double size, double gap) {
    final length = game.wordLength;
    final isSubmitted = r < game.guesses.length;
    final isCurrent = r == game.guesses.length && !game.isOver;
    final word = isSubmitted
        ? game.guesses[r]
        : isCurrent
        ? game.input
        : '';
    final states = isSubmitted
        ? scoreGuess(game.guesses[r], game.target)
        : null;
    final isWinningRow =
        game.status == GameStatus.won && r == game.guesses.length - 1;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int c = 0; c < length; c++)
          Padding(
            padding: EdgeInsets.only(right: c == length - 1 ? 0 : gap),
            child: Tile(
              letter: c < word.length ? word[c] : '',
              state: states?[c],
              size: size,
              revealDelay: GameController.revealStep * c,
              // Hinted letters show faintly where the player can still type
              hint: isCurrent && c >= word.length && game.hints.contains(c)
                  ? game.target[c]
                  : null,
              celebrate: isWinningRow,
              celebrateDelay:
                  GameController.revealStep * length +
                  GameController.flipDuration +
                  Duration(milliseconds: 90 * c),
            ),
          ),
      ],
    );

    if (!isCurrent) return row;
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          math.sin(shake.value * math.pi * 6) * 8 * (1 - shake.value),
          0,
        ),
        child: child,
      ),
      child: row,
    );
  }
}

/// One letter square. Pops when a letter is typed and flips to show its
/// colour when the guess is submitted.
class Tile extends StatefulWidget {
  final String letter;
  final LetterState? state;
  final double size;
  final Duration revealDelay;
  final String? hint;
  final bool celebrate;
  final Duration celebrateDelay;

  const Tile({
    super.key,
    required this.letter,
    required this.state,
    required this.size,
    this.revealDelay = Duration.zero,
    this.hint,
    this.celebrate = false,
    this.celebrateDelay = Duration.zero,
  });

  @override
  State<Tile> createState() => _TileState();
}

class _TileState extends State<Tile> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: GameController.flipDuration,
    // A tile that already has a colour when first built (a restored game)
    // shows it straight away.
    value: widget.state != null ? 1 : 0,
  );
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Tile old) {
    super.didUpdateWidget(old);
    if (old.letter.isEmpty &&
        widget.letter.isNotEmpty &&
        widget.state == null) {
      _pop.forward(from: 0).then((_) => _pop.reverse());
    }
    if (old.state == null && widget.state != null) {
      Future.delayed(widget.revealDelay, () {
        if (mounted) _flip.forward(from: 0);
      });
    }
    if (old.state != null && widget.state == null) _flip.value = 0;
    if (!old.celebrate && widget.celebrate) {
      Future.delayed(widget.celebrateDelay, () {
        if (mounted) _bounce.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _flip.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_pop, _flip, _bounce]),
      builder: (context, _) {
        final flipped = _flip.value >= 0.5;
        final angle = _flip.value * math.pi;
        final lift = math.sin(_bounce.value * math.pi) * -widget.size * 0.35;

        Color fill = Colors.transparent;
        Color border = widget.letter.isEmpty
            ? colors.emptyBorder
            : colors.filledBorder;
        Color textColor = scheme.onSurface;
        if (flipped && widget.state != null) {
          fill = switch (widget.state!) {
            LetterState.correct => colors.correct,
            LetterState.present => colors.present,
            LetterState.absent => colors.absent,
          };
          border = fill;
          textColor = colors.onTile;
        }

        final showHint = widget.letter.isEmpty && widget.hint != null;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: 1 + _pop.value * 0.1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(flipped ? angle - math.pi : angle),
              child: Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(widget.size * 0.12),
                  border: Border.all(
                    color: showHint
                        ? colors.hint.withValues(alpha: 0.7)
                        : border,
                    width: 2,
                  ),
                ),
                child: Text(
                  (showHint ? widget.hint! : widget.letter).toUpperCase(),
                  style: TextStyle(
                    fontSize: widget.size * 0.5,
                    fontWeight: FontWeight.w800,
                    color: showHint
                        ? colors.hint.withValues(alpha: 0.75)
                        : textColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
