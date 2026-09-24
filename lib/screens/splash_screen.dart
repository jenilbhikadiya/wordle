import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    Timer(Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
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
              animation: _rotateController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SplashBackgroundPainter(_rotateController.value),
                  size: Size.infinite,
                );
              },
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated logo container
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFF0ff4c6).withOpacity(0.3 * _glowAnimation.value),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF0ff4c6).withOpacity(0.5 * _glowAnimation.value),
                                  blurRadius: 60 * _glowAnimation.value,
                                  spreadRadius: 20 * _glowAnimation.value,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.grid_4x4,
                              size: 80,
                              color: Color(0xFF0ff4c6),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 40),
                      // Title
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Color(0xFF0ff4c6),
                                Color(0xFF00d4ff),
                                Color(0xFF0ff4c6),
                              ],
                              stops: [
                                0.0,
                                _glowAnimation.value,
                                1.0,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'WORDLE',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF0ff4c6).withOpacity(0.8),
                                    blurRadius: 20,
                                  ),
                                  Shadow(
                                    color: Color(0xFF00d4ff).withOpacity(0.5),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      Text(
                        'FUTURE EDITION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFF0ff4c6).withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 60),
                      // Loading indicator
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 200,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Color(0xFF16213e),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF0ff4c6),
                                        Color(0xFF00d4ff),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.3, 0.7, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF0ff4c6).withOpacity(0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 20),
                      Text(
                        'INITIALIZING...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Color(0xFF0ff4c6).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  final double animationValue;

  _SplashBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw rotating circles
    for (int i = 0; i < 3; i++) {
      final radius = 100.0 + (i * 80.0);
      final opacity = 0.1 - (i * 0.02);
      paint.color = Color(0xFF0ff4c6).withOpacity(opacity);

      final offset = animationValue * 2 * math.pi;

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(offset * (i % 2 == 0 ? 1 : -1));

      canvas.drawCircle(Offset.zero, radius, paint);

      // Draw connecting lines
      for (int j = 0; j < 6; j++) {
        final angle = (j / 6) * 2 * math.pi;
        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius;
        canvas.drawLine(Offset.zero, Offset(x, y), paint);
      }

      canvas.restore();
    }

    // Draw grid
    paint.color = Color(0xFF0ff4c6).withOpacity(0.03);
    paint.strokeWidth = 1;

    final spacing = 40.0;
    final gridOffset = animationValue * spacing;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset((i + gridOffset) % size.width, 0),
        Offset((i + gridOffset) % size.width, size.height),
        paint,
      );
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, (i + gridOffset) % size.height),
        Offset(size.width, (i + gridOffset) % size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SplashBackgroundPainter oldDelegate) => true;
}