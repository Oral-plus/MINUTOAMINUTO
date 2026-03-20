import 'package:flutter/material.dart';

// ─── Token de colores por tema ───────────────────────────────────────────────
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color appBarBg;
  final Color fg;
  final Color fgSubtle;
  final Color border;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.appBarBg,
    required this.fg,
    required this.fgSubtle,
    required this.border,
  });

  static const dark = AppColors(
    bg: Color(0xFF0D0D0D),
    surface: Color(0xFF161616),
    surfaceAlt: Color(0xFF141414),
    appBarBg: Color(0xFF0D0D0D),
    fg: Color(0xFFFFFFFF),
    fgSubtle: Color(0x61FFFFFF), // white38
    border: Color(0x14FFFFFF),   // white8%
  );

  static const light = AppColors(
    bg: Color(0xFFF0F0F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F7F7),
    appBarBg: Color(0xFF0D0D0D), // AppBar always dark (brand identity)
    fg: Color(0xFF0D0D0D),
    fgSubtle: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? appBarBg,
    Color? fg,
    Color? fgSubtle,
    Color? border,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      appBarBg: appBarBg ?? this.appBarBg,
      fg: fg ?? this.fg,
      fgSubtle: fgSubtle ?? this.fgSubtle,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      appBarBg: Color.lerp(appBarBg, other.appBarBg, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      fgSubtle: Color.lerp(fgSubtle, other.fgSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get ac => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── Temas Material ──────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);
  static ThemeData get light => _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A0A0A),
        primary: const Color(0xFF0A0A0A),
        secondary: const Color(0xFF262626),
        error: const Color(0xFFA3A3A3),
        surface: colors.surface,
        brightness: brightness,
      ),
      extensions: [colors],
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: colors.bg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 4,
        backgroundColor: colors.appBarBg,
        foregroundColor: const Color(0xFFFFFFFF),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? colors.surface : const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.25),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF374151)),
      ),
    );
  }
}
