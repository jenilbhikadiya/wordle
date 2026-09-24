import 'package:flutter/material.dart';
import 'dart:math' as math; // Import math library for pi

class LetterBox extends StatefulWidget {
  final String letter;
  final Color bg;
  final int delay;

  LetterBox({
    this.letter = '',
    this.bg = Colors.transparent,
    this.delay = 0,
  });

  @override
  _LetterBoxState createState() => _LetterBoxState();
}

class _LetterBoxState extends State<LetterBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotateAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(LetterBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bg != widget.bg && widget.bg != Colors.transparent) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getGlowColor() {
    if (widget.bg == Colors.green) return Colors.greenAccent;
    if (widget.bg == Colors.yellow) return Colors.yellowAccent;
    if (widget.bg == Colors.grey) return Colors.white24;
    return Colors.cyanAccent;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_rotateAnimation.value * math.pi), // Use math.pi
            child: Container(
              margin: EdgeInsets.all(4),
              width: 48,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.bg == Colors.transparent
                    ? Color(0xFF1a1a2e)
                    : widget.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.bg == Colors.transparent
                      ? Color(0xFF0ff4c6).withOpacity(0.3)
                      : _getGlowColor(),
                  width: 2,
                ),
                boxShadow: widget.bg != Colors.transparent
                    ? [
                  BoxShadow(
                    color: _getGlowColor()
                        .withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 12 * _glowAnimation.value,
                    spreadRadius: 2 * _glowAnimation.value,
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Color(0xFF0ff4c6).withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
                gradient: widget.bg != Colors.transparent
                    ? null
                    : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                  ],
                ),
              ),
              // CHANGE: Wrap Text in a Transform to counter-rotate it
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                // If rotation is > 0.5 (90 deg), flip text 180 deg (pi)
                  ..rotateY(_rotateAnimation.value > 0.5 ? math.pi : 0),
                child: Text(
                  widget.letter.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: widget.bg == Colors.transparent
                        ? Color(0xFF0ff4c6)
                        : Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: widget.bg == Colors.transparent
                            ? Color(0xFF0ff4c6).withOpacity(0.5)
                            : Colors.black45,
                        blurRadius: 4,
                      ),
                    ],
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
