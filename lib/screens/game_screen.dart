import 'package:flutter/material.dart';

import '../utils/word_loader.dart';
import '../widgets/letter_box.dart';
import '../widgets/keyboard.dart';
import 'dart:math' as math;

class GameScreen extends StatefulWidget {
  final int wordLength;
  GameScreen({required this.wordLength});

  @override
  _GameScreenState createState() => _GameScreenState();
}

enum LetterState { correct, present, absent, none }

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int maxAttempts = 6;
  late List<String> dictionary;
  late String target;
  List<List<String>> board = [];
  int currentRow = 0;
  int currentCol = 0;
  Map<String, Color> keyColors = {};
  bool loaded = false;
  String feedbackMessage = '';
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
    dictionary = await WordLoader.loadWords(widget.wordLength);
    dictionary = dictionary.map((e) => e.toLowerCase()).toList();
    
    // Load easy words for target selection
    final easyWords = await WordLoader.loadEasyWords(widget.wordLength);
    final easyWordsList = easyWords.map((e) => e.toLowerCase()).toList();
    
    // Pick random target from easy words
    target = (easyWordsList..shuffle()).first;
    
    board = List.generate(
        maxAttempts, (_) => List.generate(widget.wordLength, (_) => ''));
    keyColors = {};
    currentRow = 0;
    currentCol = 0;
    loaded = true;
    feedbackMessage = '';
    setState(() {});
  }

  void _onKey(String k) {
    if (!loaded) return;
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

    final resultColors = _colorForGuess(guess, target);
    // update key colors based on result
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

    setState(() {});

    if (guess == target) {
      setState(() => showParticles = true);
      _particleController.forward(from: 0);
      final pts = PointsService.pointsForLength(widget.wordLength);
      await PointsService.addPoints(pts);
      await Future.delayed(Duration(milliseconds: 800));
      _showWinDialog();
      return;
    }

    if (currentRow + 1 >= maxAttempts) {
      await Future.delayed(Duration(milliseconds: 800));
      _showLoseDialog();
      return;
    }

    currentRow++;
    currentCol = 0;
  }

  void _showFeedback(String message) {
    setState(() => feedbackMessage = message);
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted) setState(() => feedbackMessage = '');
    });
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FuturisticDialog(
        title: 'VICTORY!',
        content:
        'Word: ${target.toUpperCase()}\nAttempts: ${currentRow + 1}/$maxAttempts',
        isWin: true,
        onPlayAgain: () {
          Navigator.pop(context);
          setState(() => showParticles = false);
          _startGame();
        },
      ),
    );
  }

  void _showLoseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FuturisticDialog(
        title: 'GAME OVER',
        content: 'Target was ${target.toUpperCase()}',
        isWin: false,
        onPlayAgain: () {
          Navigator.pop(context);
          _startGame();
        },
      ),
    );
  }

  List<Color> _colorForGuess(String guess, String target) {
    final colors = List<Color>.filled(widget.wordLength, Colors.grey);
    final targetChars = target.split('');
    final guessed = guess.split('');

    for (int i = 0; i < widget.wordLength; i++) {
      if (guessed[i] == targetChars[i]) {
        colors[i] = Colors.green;
        targetChars[i] = '';
      }
    }
    for (int i = 0; i < widget.wordLength; i++) {
      if (colors[i] == Colors.green) continue;
      final idx = targetChars.indexOf(guessed[i]);
      if (idx != -1) {
        colors[i] = Colors.yellow;
        targetChars[idx] = '';
      }
    }
    return colors;
  }

  Color _boxColorFor(int row, int col) {
    if (row < currentRow) {
      final guess = board[row].join('').toLowerCase();
      final colors = _colorForGuess(guess, target);
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
      body: Container(
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
                  painter: _HomeBackgroundPainter(_backgroundController.value),
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
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                Color(0xFFff006e).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Color(0xFFff006e), width: 2),
                              ),
                              child: Text(
                                feedbackMessage,
                                style: TextStyle(
                                  color: Color(0xFFff006e),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            )
                                : null, // Show null when empty to collapse padding
                          ),
                        ),
                        SizedBox(height: 10),
                        // Grid of attempts with shake animation
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final offset =
                                math.sin(_shakeController.value * math.pi * 4) *
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
                                children: List.generate(widget.wordLength, (c) {
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
            if (showParticles) _ParticleEffect(controller: _particleController),
          ],
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

  _FuturisticAppBar({
    required this.wordLength,
    required this.currentAttempt,
    required this.maxAttempts,
    required this.pulseAnimation,
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
                  '$wordLength-LETTER MODE',
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
                      border: Border.all(
                        color: Color(0xFF0ff4c6),
                        width: 2,
                      ),
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
          border:
          Border.all(color: Color(0xFF0ff4c6).withOpacity(0.5), width: 2),
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
      final x = (size.width * 0.2 * (i + 1)) +
          (math.sin(animationValue * 2 * math.pi + i) * 50);
      final y = (size.height * 0.3) +
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
      paint.color = (i % 3 == 0
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

  _FuturisticDialog({
    required this.title,
    required this.content,
    required this.isWin,
    required this.onPlayAgain,
  });

  @override
  __FuturisticDialogState createState() => __FuturisticDialogState();
}

class __FuturisticDialogState extends State<_FuturisticDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

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

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

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
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    accentColor.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 30 * _glowAnimation.value,
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                ],
              ),
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
                  SizedBox(height: 30),
                  GestureDetector(
                    onTap: widget.onPlayAgain,
                    child: Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withOpacity(0.8),
                            accentColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: accentColor,
                          width: 2,
                        ),
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
                            'PLAY AGAIN',
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
            );
          },
        ),
      ),
    );
  }
}

