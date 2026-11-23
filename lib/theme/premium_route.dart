import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A page that always uses the premium obsidian-and-gold theme, so sheets and
/// dialogs it opens are themed too.
Route<T> premiumRoute<T>(Widget page) => MaterialPageRoute<T>(
  builder: (_) => Theme(data: AppTheme.premium(), child: page),
);

/// The premium backdrop: obsidian with a faint gold glow from the top.
class PremiumBackdrop extends StatelessWidget {
  final Widget child;
  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.3,
          colors: [Color(0xFF2A2214), AppTheme.obsidian],
        ),
      ),
      child: child,
    );
  }
}
