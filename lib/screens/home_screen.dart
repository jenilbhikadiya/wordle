import 'dart:ui';

import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'game_screen.dart';
import '../utils/game_logic.dart';
import '../utils/stats_service.dart';
import '../utils/word_loader.dart';
import '../widgets/stats_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  int _points = 0;
  bool _daily = true;
  bool _hardMode = false;
  // Today's daily result per word length: guesses used, 0 for a loss.
  Map<int, int?> _dailyResults = {};

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 15),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadPoints();
    SettingsService.getHardMode().then((v) {
      if (mounted) setState(() => _hardMode = v);
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPoints() async {
    final p = await PointsService.getPoints();
    final today = dateKey(DateTime.now());
    final results = <int, int?>{};
    for (final len in [4, 5, 6]) {
      results[len] = await DailyService.getResult(len, today);
    }
    if (!mounted) return;
    setState(() {
      _points = p;
      _dailyResults = results;
    });
  }

  String? _subtitleFor(int letters) {
    if (!_daily) return 'UNLIMITED PLAY';
    final result = _dailyResults[letters];
    if (result == null) return 'DAILY · READY';
    return result == 0 ? 'DAILY · MISSED' : 'DAILY · SOLVED $result/6';
  }

  Widget _buildModeToggle() {
    const accent = Color(0xFF0ff4c6);
    Widget option(String label, bool value) {
      final selected = _daily == value;
      return GestureDetector(
        onTap: () => setState(() => _daily = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : accent.withOpacity(0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withOpacity(0.6), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [option('DAILY', true), option('UNLIMITED', false)],
          ),
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            setState(() => _hardMode = !_hardMode);
            SettingsService.setHardMode(_hardMode);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _hardMode,
                activeColor: Color(0xFFff006e),
                onChanged: (v) {
                  setState(() => _hardMode = v);
                  SettingsService.setHardMode(v);
                },
              ),
              Text(
                'HARD MODE',
                style: TextStyle(
                  color: _hardMode
                      ? Color(0xFFff006e)
                      : accent.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Text(
          _hardMode
              ? 'Revealed hints must be used · +3 bonus points'
              : 'Hints you find can be ignored',
          style: TextStyle(color: accent.withOpacity(0.45), fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f0f1e),
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background
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
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Center(
                    // This Center widget horizontally centers the Column
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Grouped header
                        Column( // <-- FIX: Was 'children: ['
                          children: [
                            SizedBox(height: 40),
                            _buildHeader(),
                          ],
                        ),

                        // Grouped buttons
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SELECT MODE',
                              style: TextStyle(
                                color: Color(0xFF0ff4c6).withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                            SizedBox(height: 20),
                            _buildModeToggle(),
                            SizedBox(height: 30),
                            _FuturisticButton(
                              letters: 4,
                              daily: _daily,
                              hardMode: _hardMode,
                              subtitle: _subtitleFor(4),
                              delay: 0,
                              pulseAnimation: _pulseController,
                              onReturn: _loadPoints,
                            ),
                            SizedBox(height: 24),
                            _FuturisticButton(
                              letters: 5,
                              daily: _daily,
                              hardMode: _hardMode,
                              subtitle: _subtitleFor(5),
                              delay: 150,
                              pulseAnimation: _pulseController,
                              onReturn: _loadPoints,
                            ),
                            SizedBox(height: 24),
                            _FuturisticButton(
                              letters: 6,
                              daily: _daily,
                              hardMode: _hardMode,
                              subtitle: _subtitleFor(6),
                              delay: 300,
                              pulseAnimation: _pulseController,
                              onReturn: _loadPoints,
                            ),
                          ],
                        ),

                        // Footer
                        Padding(
                          padding: EdgeInsets.only(top: 40, bottom: 30),
                          child: Text(
                            'CHOOSE YOUR CHALLENGE',
                            style: TextStyle(
                              color: Color(0xFF0ff4c6).withOpacity(0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale =
            1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.05);
        return Transform.scale(
          scale: scale,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF0ff4c6).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0ff4c6).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.grid_4x4,
                  size: 60,
                  color: Color(0xFF0ff4c6),
                ),
              ),
              SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Color(0xFF0ff4c6),
                    Color(0xFF00d4ff),
                  ],
                ).createShader(bounds),
                child: Text(
                  'WORDLE',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0xFF0ff4c6).withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'FUTURE EDITION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: Color(0xFF0ff4c6).withOpacity(0.6),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF0ff4c6), width: 2),
                  color: Color(0xFF0ff4c6).withOpacity(0.1),
                ),
                child: Text(
                  'POINTS: $_points',
                  style: TextStyle(
                    color: Color(0xFF0ff4c6),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => StatsDialog(),
                ),
                icon: Icon(Icons.bar_chart, color: Color(0xFF0ff4c6)),
                label: Text(
                  'STATS',
                  style: TextStyle(
                    color: Color(0xFF0ff4c6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FuturisticButton extends StatefulWidget {
  final int letters;
  final int delay;
  final AnimationController pulseAnimation;
  final VoidCallback? onReturn;
  final bool daily;
  final bool hardMode;
  final String? subtitle;

  const _FuturisticButton({
    required this.letters,
    required this.delay,
    required this.pulseAnimation,
    this.onReturn,
    this.daily = false,
    this.hardMode = false,
    this.subtitle,
  });

  @override
  __FuturisticButtonState createState() => __FuturisticButtonState();
}

class __FuturisticButtonState extends State<_FuturisticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeIn,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Color _getDifficultyColor() {
    switch (widget.letters) {
      case 4:
        return Colors.greenAccent;
      case 5:
        return Color(0xFF0ff4c6);
      case 6:
        return Color(0xFFff006e);
      default:
        return Color(0xFF0ff4c6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final difficultyColor = _getDifficultyColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    GameScreen(
                      wordLength: widget.letters,
                      daily: widget.daily,
                      hardMode: widget.hardMode,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                        CurvedAnimation(
                            parent: animation, curve: Curves.easeOut),
                      ),
                      child: child,
                    ),
                  );
                },
                transitionDuration: Duration(milliseconds: 400),
              ),
            ).then((_) {
              if (widget.onReturn != null) widget.onReturn!();
            });
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 280,
              height: 100,
              transform: Matrix4.identity()
                ..scale(_isPressed ? 0.95 : _isHovered ? 1.05 : 1.0),
              child: Stack(
                children: [
                  // Background glow
                  if (_isHovered)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: difficultyColor.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Main button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF16213e).withOpacity(0.9),
                          Color(0xFF1a1a2e).withOpacity(0.9),
                        ],
                      ),
                      border: Border.all(
                        color: _isHovered
                            ? difficultyColor
                            : difficultyColor.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: _isPressed
                          ? []
                          : [
                        BoxShadow(
                          color: difficultyColor.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Animated scan line effect
                        AnimatedBuilder(
                          animation: widget.pulseAnimation,
                          builder: (context, child) {
                            return Positioned(
                              left: 0,
                              right: 0,
                              top: widget.pulseAnimation.value * 100,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      difficultyColor.withOpacity(0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Content
                        Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Letter count
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      difficultyColor.withOpacity(0.3),
                                      difficultyColor.withOpacity(0.1),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: difficultyColor,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${widget.letters}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: difficultyColor,
                                      shadows: [
                                        Shadow(
                                          color:
                                          difficultyColor.withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
                              // Text info
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.letters} LETTERS',
                                      style: TextStyle(
                                        fontSize: 18, // <-- FIX WAS 20
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    if (widget.subtitle != null)
                                      Text(
                                        widget.subtitle!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: difficultyColor.withOpacity(0.8),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Arrow
                              Icon(
                                Icons.arrow_forward_ios,
                                color: difficultyColor.withOpacity(0.7),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

