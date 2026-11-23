import 'package:flutter/material.dart';

/// Colours specific to the game that Material's ColorScheme has no slot for.
@immutable
class GameColors extends ThemeExtension<GameColors> {
  final Color correct;
  final Color present;
  final Color absent;
  final Color onTile;
  final Color emptyBorder;
  final Color filledBorder;
  final Color key;
  final Color onKey;
  final Color streak;
  final Color hint;

  /// Tiles get a metallic sheen and a soft glow, used by the Extreme theme.
  final bool luxe;

  const GameColors({
    required this.correct,
    required this.present,
    required this.absent,
    required this.onTile,
    required this.emptyBorder,
    required this.filledBorder,
    required this.key,
    required this.onKey,
    required this.streak,
    required this.hint,
    this.luxe = false,
  });

  static const light = GameColors(
    correct: Color(0xFF2F9E66),
    present: Color(0xFFD6A419),
    absent: Color(0xFF7C818A),
    onTile: Colors.white,
    emptyBorder: Color(0xFFD9DCE1),
    filledBorder: Color(0xFF8A8F98),
    key: Color(0xFFE4E7EC),
    onKey: Color(0xFF1B1D22),
    streak: Color(0xFFF2711C),
    hint: Color(0xFFD6A419),
  );

  static const dark = GameColors(
    correct: Color(0xFF34A86E),
    present: Color(0xFFC99A1A),
    absent: Color(0xFF3C4048),
    onTile: Colors.white,
    emptyBorder: Color(0xFF34373E),
    filledBorder: Color(0xFF666B75),
    key: Color(0xFF2B2E35),
    onKey: Color(0xFFF1F2F4),
    streak: Color(0xFFFF8A3D),
    hint: Color(0xFFE5B530),
  );

  /// Obsidian and gold, for the Extreme levels.
  static const premium = GameColors(
    correct: Color(0xFFC9A13B),
    present: Color(0xFF8B5CF6),
    absent: Color(0xFF26252C),
    onTile: Colors.white,
    emptyBorder: Color(0xFF2F2B24),
    filledBorder: Color(0xFF8C7A4E),
    key: Color(0xFF1F1E25),
    onKey: Color(0xFFF4EEDF),
    streak: Color(0xFFE6C46A),
    hint: Color(0xFFE6C46A),
    luxe: true,
  );

  static GameColors of(BuildContext context) =>
      Theme.of(context).extension<GameColors>()!;

  @override
  GameColors copyWith() => this;

  @override
  GameColors lerp(ThemeExtension<GameColors>? other, double t) {
    if (other is! GameColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return GameColors(
      correct: l(correct, other.correct),
      present: l(present, other.present),
      absent: l(absent, other.absent),
      onTile: l(onTile, other.onTile),
      emptyBorder: l(emptyBorder, other.emptyBorder),
      filledBorder: l(filledBorder, other.filledBorder),
      key: l(key, other.key),
      onKey: l(onKey, other.onKey),
      streak: l(streak, other.streak),
      hint: l(hint, other.hint),
      luxe: t < 0.5 ? luxe : other.luxe,
    );
  }
}

class AppTheme {
  static const _brand = Color(0xFF4F5BD5);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: _brand,
      surface: const Color(0xFFF8F8FA),
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF0F1F4),
      onSurface: const Color(0xFF1B1D22),
      onSurfaceVariant: const Color(0xFF666B75),
      outlineVariant: const Color(0xFFE2E4E9),
    ),
    GameColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF8C95F0),
      onPrimary: const Color(0xFF14172E),
      surface: const Color(0xFF121317),
      surfaceContainerLow: const Color(0xFF1B1D22),
      surfaceContainer: const Color(0xFF23262C),
      onSurface: const Color(0xFFF1F2F4),
      onSurfaceVariant: const Color(0xFF9EA3AD),
      outlineVariant: const Color(0xFF2E3138),
    ),
    GameColors.dark,
  );

  /// Gold on obsidian, used for the Extreme levels whatever the app theme.
  static const gold = Color(0xFFE6C46A);
  static const goldDeep = Color(0xFFB08A2E);
  static const obsidian = Color(0xFF0B0B0E);
  static const amethyst = Color(0xFF8B5CF6);

  /// Gold gradient for premium accents.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6E3A1), gold, goldDeep],
  );

  static ThemeData premium() => _build(
    ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark).copyWith(
      primary: gold,
      onPrimary: const Color(0xFF1C1505),
      secondary: amethyst,
      surface: obsidian,
      surfaceContainerLow: const Color(0xFF15141A),
      surfaceContainer: const Color(0xFF1E1D24),
      onSurface: const Color(0xFFF4EEDF),
      onSurfaceVariant: const Color(0xFFA9A18F),
      outlineVariant: const Color(0xFF3A3326),
      error: const Color(0xFFFF6B6B),
    ),
    GameColors.premium,
  );

  static ThemeData _build(ColorScheme scheme, GameColors game) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [game],
    );
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: TextStyle(
          color: scheme.surface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
