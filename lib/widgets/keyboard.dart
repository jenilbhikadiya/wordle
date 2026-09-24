import 'package:flutter/material.dart';

typedef KeyTap = void Function(String);

class Keyboard extends StatelessWidget {
  final Map<String, Color> keyColors;
  final KeyTap onTap;

  Keyboard({required this.keyColors, required this.onTap});

  final List<String> rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  Color _getKeyGlow(Color? color) {
    if (color == Colors.green) return Colors.greenAccent;
    if (color == Colors.yellow) return Colors.yellowAccent;
    if (color == Colors.grey) return Colors.white24;
    return Color(0xFF0ff4c6);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // CHANGE: Use horizontal padding, vertical will be handled by Column
      padding: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0f0f1e).withOpacity(0.8),
            Color(0xFF1a1a2e).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0ff4c6).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      // CHANGE: Wrap Column in SafeArea to avoid home bar
      child: SafeArea(
        top: false, // Only apply to bottom
        child: Padding(
          // CHANGE: Add vertical padding inside safe area
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r in rows)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: r.split('').map((k) {
                      final color = keyColors[k];
                      return Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: _KeyButton(
                          letter: k,
                          color: color,
                          onTap: () => onTap(k),
                          glowColor: _getKeyGlow(color),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SpecialKeyButton(
                    label: 'ENTER',
                    icon: Icons.keyboard_return,
                    onTap: () => onTap('ENTER'),
                  ),
                  SizedBox(width: 12),
                  _SpecialKeyButton(
                    label: 'DEL',
                    icon: Icons.backspace_outlined,
                    onTap: () => onTap('DEL'),
                  ),
                ],
              ),
              // CHANGE: Removed extra SizedBox, padding is handled above
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String letter;
  final Color? color;
  final VoidCallback onTap;
  final Color glowColor;

  _KeyButton({
    required this.letter,
    required this.color,
    required this.onTap,
    required this.glowColor,
  });

  @override
  __KeyButtonState createState() => __KeyButtonState();
}

class __KeyButtonState extends State<_KeyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? Color(0xFF16213e);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        width: 32,
        height: 45,
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.glowColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: widget.glowColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgColor,
              bgColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Text(
          widget.letter.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: widget.color == null ? Color(0xFF0ff4c6) : Colors.white,
            shadows: [
              Shadow(
                color: widget.glowColor.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialKeyButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _SpecialKeyButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  __SpecialKeyButtonState createState() => __SpecialKeyButtonState();
}

class __SpecialKeyButtonState extends State<_SpecialKeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0ff4c6).withOpacity(0.2),
              Color(0xFF00d4ff).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color(0xFF0ff4c6).withOpacity(0.6),
            width: 2,
          ),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: Color(0xFF0ff4c6).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: Color(0xFF0ff4c6),
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0ff4c6),
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Color(0xFF0ff4c6).withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
