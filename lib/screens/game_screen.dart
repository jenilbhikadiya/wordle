import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/game_logic.dart';
import '../utils/stats_service.dart';
import '../utils/word_loader.dart';
import '../widgets/letter_box.dart';
import '../widgets/keyboard.dart';
import '../widgets/stats_panel.dart';
import 'dart:math' as math;

class GameScreen extends StatefulWidget {
  final int wordLength;
  final bool daily;
  final bool hardMode;
  GameScreen({
    required this.wordLength,
    this.daily = false,
    this.hardMode = false,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int maxAttempts = 6;
  static const int maxHints = 2;
  late Set<String> dictionary;
  late String target;
  List<List<String>> board = [];
  List<String> guesses = [];
  int currentRow = 0;
  int currentCol = 0;
  Map<String, Color> keyColors = {};
  bool loaded = false;
  bool gameOver = false;
  String feedbackMessage = '';
  bool feedbackIsInfo = false;
  // Positions of target letters revealed with hints.
  Set<int> hintPositions = {};
  late String dailyDate;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _backgroundController; // NEW controller
  bool showParticles = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    // NEW: Initialize background controller
    _backgroundController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 15),
    )..repeat();
    _startGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _backgroundController.dispose(); // NEW: Dispose controller
    super.dispose();
  }

  Future<void> _startGame() async {
    // Load full dictionary for validation
    final words = await WordLoader.loadWords(widget.wordLength);

    // Load easy words for target selection
    final easyWords = await WordLoader.loadEasyWords(widget.wordLength);
    final easyWordsList = easyWords.map((e) => e.toLowerCase()).toList();
    dictionary = {...words, ...easyWordsList};

    final now = DateTime.now();
    dailyDate = dateKey(now);
    if (widget.daily) {
      // Same word for everyone today
      target = dailyWord(easyWordsList, widget.wordLength, now);
    } else {
      // Pick random target from easy words
      target = (easyWordsList..shuffle()).first;
    }

    board = List.generate(
      maxAttempts,
      (_) => List.generate(widget.wordLength, (_) => ''),
    );
    guesses = [];
    keyColors = {};
    hintPositions = {};
    currentRow = 0;
    currentCol = 0;
    gameOver = false;
    feedbackMessage = '';

    // Restore today's daily progress, if any
    if (widget.daily) {
      final saved = await DailyService.getGuesses(widget.wordLength, dailyDate);
      for (final g in saved) {
        if (guesses.length >= maxAttempts || g.length != widget.wordLength)
          break;
        board[guesses.length] = g.split('');
        guesses.add(g);
        _updateKeyColors(g);
      }
      final finished = guesses.isNotEmpty &&
          (guesses.last == target || guesses.length >= maxAttempts);
      currentRow = finished ? guesses.length - 1 : guesses.length;
      hintPositions = (await DailyService.getHints(widget.wordLength, dailyDate))
          .where((i) => i >= 0 && i < widget.wordLength)
          .toSet();
    }

    loaded = true;
    if (!mounted) return;
    setState(() {});

    if (widget.daily && guesses.isNotEmpty) {
      final won = guesses.last == target;
      if (won || guesses.length >= maxAttempts) {
        gameOver = true;
        final stats = await StatsService.getStats(widget.wordLength);
        if (mounted) _showEndDialog(won: won, stats: stats);
      }
    }
  }

  void _onKey(String k) {
    if (!loaded || gameOver) return;
    if (k == 'DEL') {
      if (currentCol > 0) {
        setState(() {
          currentCol--;
          board[currentRow][currentCol] = '';
        });
      }
      return;
    } else if (k == 'ENTER') {
      _submitGuess();
      return;
    }
    if (currentCol < widget.wordLength) {
      setState(() {
        board[currentRow][currentCol] = k;
        currentCol++;
      });
    }
  }

  // Lets the game be played with a physical keyboard on web and desktop.
  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _onKey('ENTER');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onKey('DEL');
      return KeyEventResult.handled;
    }
    final ch = event.character?.toLowerCase();
    if (ch != null && ch.length == 1 && RegExp(r'[a-z]').hasMatch(ch)) {
      _onKey(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _updateKeyColors(String guess) {
    final resultColors = _colorForGuess(guess, target);
    for (int i = 0; i < widget.wordLength; i++) {
      final ch = guess[i];
      final color = resultColors[i];
      final existing = keyColors[ch];
      if (existing == Colors.green) continue;
      if (color == Colors.green)
        keyColors[ch] = Colors.green;
      else if (color == Colors.yellow && existing != Colors.green)
        keyColors[ch] = Colors.yellow;
      else if (color == Colors.grey && existing == null)
        keyColors[ch] = Colors.grey;
    }
  }

  void _submitGuess() async {
    final guess = board[currentRow].join('').toLowerCase();
    if (guess.length != widget.wordLength) {
      _showFeedback('Complete the word!');
      _shakeController.forward(from: 0);
      return;
    }
    if (!dictionary.contains(guess)) {
      _showFeedback('Not in word list');
      _shakeController.forward(from: 0);
      return;
    }
    if (widget.hardMode) {
      final violation = hardModeViolation(guess, guesses, target);
      if (violation != null) {
        _showFeedback(violation);
        _shakeController.forward(from: 0);
        return;
      }
    }

    guesses.add(guess);
    _updateKeyColors(guess);
    if (widget.daily) {
      DailyService.saveGuesses(widget.wordLength, dailyDate, guesses);
    }

    final won = guess == target;
    final lost = !won && guesses.length >= maxAttempts;
    if (won || lost) gameOver = true;
    setState(() {});

    if (won) {
      setState(() => showParticles = true);
      _particleController.forward(from: 0);
      await PointsService.addPoints(_pointsForWin());
    }

    if (won || lost) {
      final stats = await StatsService.recordGame(
        widget.wordLength,
        won: won,
        attempts: guesses.length,
      );
      if (widget.daily) {
        await DailyService.saveResult(
          widget.wordLength,
          dailyDate,
          won ? guesses.length : 0,
        );
      }
      // Let the tile flip finish before the dialog covers it
      await Future.delayed(
        Duration(milliseconds: 100 * widget.wordLength + 700),
      );
      if (mounted) _showEndDialog(won: won, stats: stats);
      return;
    }

    currentRow++;
    currentCol = 0;
  }

  // Hard mode earns a bonus, every hint used costs some of the reward.
  int _pointsForWin() {
    final base = PointsService.pointsForLength(widget.wordLength);
    final bonus = widget.hardMode ? 3 : 0;
    return math.max(1, base + bonus - hintPositions.length * 2);
  }

  void _useHint() {
    if (!loaded || gameOver) return;
    if (hintPositions.length >= maxHints) {
      _showFeedback('No hints left');
      return;
    }
    // Only reveal letters the player has not already placed
    final solved = <int>{};
    for (final g in guesses) {
      for (int i = 0; i < widget.wordLength; i++) {
        if (g[i] == target[i]) solved.add(i);
      }
    }
    final candidates = List<int>.generate(
      widget.wordLength,
      (i) => i,
    ).where((i) => !solved.contains(i) && !hintPositions.contains(i)).toList();
    if (candidates.isEmpty) {
      _showFeedback('Nothing left to reveal');
      return;
    }
    candidates.shuffle();
    setState(() => hintPositions.add(candidates.first));
    if (widget.daily) {
      DailyService.saveHints(widget.wordLength, dailyDate, hintPositions);
    }
    _showFeedback('Hint costs 2 points from your reward', info: true);
  }

  void _showFeedback(String message, {bool info = false}) {
    setState(() {
      feedbackMessage = message;
      feedbackIsInfo = info;
    });
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted && feedbackMessage == message) {
        setState(() => feedbackMessage = '');
      }
    });
  }

  Future<void> _share() async {
    final text = shareText(
      guesses: guesses,
      target: target,
      wordLength: widget.wordLength,
      maxAttempts: maxAttempts,
      won: guesses.isNotEmpty && guesses.last == target,
      hardMode: widget.hardMode,
      hintsUsed: hintPositions.length,
      dailyDate: widget.daily ? DateTime.now() : null,
    );
    await Clipboard.setData(ClipboardData(text: text));
  }

  String _timeUntilNextDaily() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }

  void _showEndDialog({required bool won, required GameStats stats}) {
    final content = won
        ? 'Word: ${target.toUpperCase()}\nAttempts: ${guesses.length}/$maxAttempts'
        : 'Target was ${target.toUpperCase()}';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FuturisticDialog(
        title: won ? 'VICTORY!' : 'GAME OVER',
        content: content,
        isWin: won,
        stats: stats,
        highlightAttempt: won ? guesses.length : null,
        footer: widget.daily ? 'Next daily in ${_timeUntilNextDaily()}' : null,
        onShare: _share,
        actionLabel: widget.daily ? 'MENU' : 'PLAY AGAIN',
        onPlayAgain: () {
          Navigator.pop(context);
          if (widget.daily) {
            Navigator.pop(context);
            return;
          }
          setState(() => showParticles = false);
          _startGame();
        },
      ),
    );
  }

  List<Color> _colorForGuess(String guess, String target) {
    return scoreGuess(guess, target).map((s) {
      switch (s) {
        case LetterState.correct:
          return Colors.green;
        case LetterState.present:
          return Colors.yellow;
        case LetterState.absent:
          return Colors.grey;
      }
    }).toList();
  }

  Color get _feedbackColor =>
      feedbackIsInfo ? Color(0xFFffd60a) : Color(0xFFff006e);

  // Revealed hint letters in their positions, e.g. _ R _ _ E
  Widget _buildHintRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb, color: Color(0xFFffd60a), size: 16),
          SizedBox(width: 8),
          for (int i = 0; i < widget.wordLength; i++)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 2),
              width: 22,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Color(
                    0xFFffd60a,
                  ).withOpacity(hintPositions.contains(i) ? 0.9 : 0.25),
                ),
              ),
              child: Text(
                hintPositions.contains(i) ? target[i].toUpperCase() : '',
                style: TextStyle(
                  color: Color(0xFFffd60a),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _boxColorFor(int row, int col) {
    if (row < guesses.length) {
      final colors = _colorForGuess(guesses[row], target);
      return colors[col];
    } else if (row == currentRow && board[row][col] != '') {
      return Colors.grey.shade300;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0f0f1e), Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0ff4c6)),
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'INITIALIZING...',
                  style: TextStyle(
                    color: Color(0xFF0ff4c6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onHardwareKey,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0f0f1e), Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
          ),
          child: Stack(
            children: [
              // NEW: Animated background from home_screen.dart
              AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _HomeBackgroundPainter(
                      _backgroundController.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
              // Main content
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // This Column groups the top content
                      Column(
                        children: [
                          _FuturisticAppBar(
                            wordLength: widget.wordLength,
                            currentAttempt: currentRow + 1,
                            maxAttempts: maxAttempts,
                            pulseAnimation: _pulseController,
                            daily: widget.daily,
                            hardMode: widget.hardMode,
                            hintsLeft: maxHints - hintPositions.length,
                            onHint: gameOver ? null : _useHint,
                          ),
                          SizedBox(height: 10),
                          // Feedback message
                          AnimatedOpacity(
                            opacity: feedbackMessage.isNotEmpty ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 300),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: feedbackMessage.isNotEmpty
                                  ? Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _feedbackColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _feedbackColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        feedbackMessage,
                                        style: TextStyle(
                                          color: _feedbackColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    )
                                  : null, // Show null when empty to collapse padding
                            ),
                          ),
                          if (hintPositions.isNotEmpty) _buildHintRow(),
                          SizedBox(height: 10),
                          // Grid of attempts with shake animation
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final offset =
                                  math.sin(
                                    _shakeController.value * math.pi * 4,
                                  ) *
                                  10;
                              return Transform.translate(
                                offset: Offset(offset, 0),
                                child: child,
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(maxAttempts, (r) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(widget.wordLength, (
                                    c,
                                  ) {
                                    final letter = board[r][c];
                                    final bg = _boxColorFor(r, c);
                                    return LetterBox(
                                      letter: letter,
                                      bg: bg,
                                      delay: c * 100,
                                    );
                                  }),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      // Add padding and spacing for the keyboard
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Keyboard(keyColors: keyColors, onTap: _onKey),
                      ),
                    ],
                  ),
                ),
              ),
              // Victory particles
              if (showParticles)
                _ParticleEffect(controller: _particleController),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuturisticAppBar extends StatelessWidget {
  final int wordLength;
  final int currentAttempt;
  final int maxAttempts;
  final AnimationController pulseAnimation;
  final bool daily;
  final bool hardMode;
  final int hintsLeft;
  final VoidCallback? onHint;

  _FuturisticAppBar({
    required this.wordLength,
    required this.currentAttempt,
    required this.maxAttempts,
    required this.pulseAnimation,
    this.daily = false,
    this.hardMode = false,
    this.hintsLeft = 0,
    this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Only apply SafeArea to the bottom
      bottom: false,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        // REMOVED: decoration property to make app bar transparent
        // CHANGED: Updated Row layout
        child: Row(
          children: [
            // NEW WIDGET
            _AnimatedBackButton(
              onTap: () {
                // Assumes this screen was pushed from another screen
                Navigator.pop(context);
              },
            ),
            SizedBox(width: 16), // NEW: Added spacing
            // Existing Title Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORDLE',
                  style: TextStyle(
                    color: Color(0xFF0ff4c6),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Color(0xFF0ff4c6).withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$wordLength LETTERS · ${daily ? 'DAILY' : 'UNLIMITED'}${hardMode ? ' · HARD' : ''}',
                  style: TextStyle(
                    color: Color(0xFF0ff4c6).withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            Spacer(), // NEW: Pushes counter to the right
            _HintButton(hintsLeft: hintsLeft, onTap: onHint),
            SizedBox(width: 10),
            // Existing Counter
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                final scale =
                    1.0 + (math.sin(pulseAnimation.value * 2 * math.pi) * 0.1);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF00d4ff).withOpacity(0.3),
                          Color(0xFF0ff4c6).withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFF0ff4c6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0ff4c6).withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      '$currentAttempt / $maxAttempts',
                      style: TextStyle(
                        color: Color(0xFF0ff4a6),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// NEW PRIVATE WIDGET FOR THE BACK BUTTON
class _AnimatedBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedBackButton({required this.onTap});

  @override
  State<_AnimatedBackButton> createState() => _AnimatedBackButtonState();
}

// ADDED STATE CLASS FOR THE BACK BUTTON
class _AnimatedBackButtonState extends State<_AnimatedBackButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
      widget.onTap();
    });
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.9 : 1.0;
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()..scale(scale),
        padding: const EdgeInsets.all(10.0), // Increased padding
        decoration: BoxDecoration(
          color: Color(0xFF0ff4c6).withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Color(0xFF0ff4c6).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            // Added glow
            BoxShadow(
              color: Color(0xFF0ff4c6).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: Color(0xFF0ff4c6),
          size: 20,
        ),
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final int hintsLeft;
  final VoidCallback? onTap;

  const _HintButton({required this.hintsLeft, this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFffd60a);
    final enabled = onTap != null && hintsLeft > 0;
    return Tooltip(
      message: 'Reveal a letter',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.6), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, color: color, size: 18),
                SizedBox(width: 4),
                Text(
                  '$hintsLeft',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// REMOVED: _AnimatedBackgroundGrid and _GridPainter

// NEW: Copied from home_screen.dart
class _HomeBackgroundPainter extends CustomPainter {
  final double animationValue;

  _HomeBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF0ff4c6).withOpacity(0.05)
      ..strokeWidth = 1;

    final spacing = 40.0;
    final offset = animationValue * spacing;

    // Grid
    for (double i = -spacing; i < size.width + spacing; i += spacing) {
      canvas.drawLine(
        Offset((i + offset) % (size.width + spacing), 0),
        Offset((i + offset) % (size.width + spacing), size.height),
        paint,
      );
    }

    for (double i = -spacing; i < size.height + spacing; i += spacing) {
      canvas.drawLine(
        Offset(0, (i + offset) % (size.height + spacing)),
        Offset(size.width, (i + offset) % (size.height + spacing)),
        paint,
      );
    }

    // Floating circles
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    for (int i = 0; i < 5; i++) {
      final x =
          (size.width * 0.2 * (i + 1)) +
          (math.sin(animationValue * 2 * math.pi + i) * 50);
      final y =
          (size.height * 0.3) +
          (math.cos(animationValue * 2 * math.pi + i * 0.7) * 100);
      final radius = 30.0 + (i * 10.0);

      paint.color = Color(0xFF0ff4c6).withOpacity(0.1 - (i * 0.015));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_HomeBackgroundPainter oldDelegate) => true;
}

class _ParticleEffect extends StatelessWidget {
  final AnimationController controller;

  _ParticleEffect({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final math.Random random = math.Random(42);

  _ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 50; i++) {
      final progress = (animationValue + i * 0.02) % 1.0;
      final x = size.width * (0.3 + random.nextDouble() * 0.4);
      final y = size.height * 0.5 - progress * size.height * 0.6;
      final offsetX = (random.nextDouble() - 0.5) * 100 * progress;

      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color =
          (i % 3 == 0
                  ? Color(0xFF0ff4c6)
                  : i % 3 == 1
                  ? Color(0xFF00d4ff)
                  : Colors.greenAccent)
              .withOpacity(opacity * 0.8);

      canvas.drawCircle(
        Offset(x + offsetX, y),
        4.0 * (1.0 - progress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class _FuturisticDialog extends StatefulWidget {
  final String title;
  final String content;
  final bool isWin;
  final VoidCallback onPlayAgain;
  final String actionLabel;
  final GameStats? stats;
  final int? highlightAttempt;
  final String? footer;
  final Future<void> Function()? onShare;

  _FuturisticDialog({
    required this.title,
    required this.content,
    required this.isWin,
    required this.onPlayAgain,
    this.actionLabel = 'PLAY AGAIN',
    this.stats,
    this.highlightAttempt,
    this.footer,
    this.onShare,
  });

  @override
  __FuturisticDialogState createState() => __FuturisticDialogState();
}

class __FuturisticDialogState extends State<_FuturisticDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isWin ? Color(0xFF0ff4c6) : Color(0xFFff006e);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              constraints: BoxConstraints(maxWidth: 380),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 30 * _glowAnimation.value,
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isWin ? Icons.emoji_events : Icons.refresh,
                      color: accentColor,
                      size: 60,
                    ),
                    SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      widget.content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        height: 1.5,
                        letterSpacing: 1,
                      ),
                    ),
                    if (widget.stats != null) ...[
                      SizedBox(height: 20),
                      StatsPanel(
                        stats: widget.stats!,
                        accentColor: accentColor,
                        highlightAttempt: widget.highlightAttempt,
                      ),
                    ],
                    if (widget.footer != null) ...[
                      SizedBox(height: 16),
                      Text(
                        widget.footer!,
                        style: TextStyle(
                          color: accentColor.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                    if (widget.onShare != null) ...[
                      SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await widget.onShare!();
                          if (mounted) setState(() => _copied = true);
                        },
                        icon: Icon(
                          _copied ? Icons.check : Icons.share,
                          color: accentColor,
                        ),
                        label: Text(
                          _copied ? 'COPIED TO CLIPBOARD' : 'SHARE RESULT',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accentColor, width: 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: widget.onPlayAgain,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.8),
                              accentColor.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: accentColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              widget.actionLabel,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
