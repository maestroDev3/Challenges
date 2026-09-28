import 'package:flutter/material.dart';

/// Farbwelt „Ritual“ – gemessen aus den Vorlagen (assets/branding/).
abstract final class RitualColors {
  static const background = Color(0xFF0F0E0C);
  static const gold = Color(0xFFC9A96E);
  static const cream = Color(0xFFEFE8DC);
  static const line = Color(0xFF2A2722);
}

/// Serifenschrift für Titel (assets/fonts, OFL).
const ritualSerif = 'CormorantGaramond';

/// Kontrastverhältnis nach WCAG (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Das einzige Theme der App: dunkel, Gold als Akzent, Creme für Text.
ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: RitualColors.gold,
    onPrimary: RitualColors.background,
    primaryContainer: Color(0xFF3A3224),
    onPrimaryContainer: Color(0xFFEAD9B5),
    secondary: Color(0xFFB8AE9C),
    onSecondary: RitualColors.background,
    secondaryContainer: Color(0xFF2E2A23),
    onSecondaryContainer: RitualColors.cream,
    tertiary: Color(0xFF9FB0B2),
    onTertiary: RitualColors.background,
    tertiaryContainer: Color(0xFF1F2627),
    onTertiaryContainer: Color(0xFFB4C3C5),
    error: Color(0xFFD9937E),
    onError: RitualColors.background,
    errorContainer: Color(0xFF3B211B),
    onErrorContainer: Color(0xFFF2C6B9),
    surface: RitualColors.background,
    onSurface: RitualColors.cream,
    onSurfaceVariant: Color(0xFFA89F91),
    surfaceContainerLowest: Color(0xFF0A0908),
    surfaceContainerLow: Color(0xFF171512),
    surfaceContainer: Color(0xFF1C1A16),
    surfaceContainerHigh: Color(0xFF23201B),
    surfaceContainerHighest: RitualColors.line,
    outline: Color(0xFF5C554A),
    outlineVariant: RitualColors.line,
    inverseSurface: RitualColors.cream,
    onInverseSurface: RitualColors.background,
    inversePrimary: Color(0xFF7A6232),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: RitualColors.gold,
  );

  final base = Typography.material2021(platform: TargetPlatform.android)
      .white
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  TextStyle? serif(TextStyle? s, {FontWeight weight = FontWeight.w500,
          double? size, double spacing = 0.2}) =>
      s?.copyWith(
        fontFamily: ritualSerif,
        fontWeight: weight,
        fontSize: size,
        letterSpacing: spacing,
      );
  final textTheme = base.copyWith(
    displayLarge: serif(base.displayLarge),
    displayMedium: serif(base.displayMedium),
    displaySmall: serif(base.displaySmall),
    headlineLarge: serif(base.headlineLarge, size: 38),
    headlineMedium: serif(base.headlineMedium, size: 36, spacing: 0.5),
    headlineSmall: serif(base.headlineSmall, size: 28),
    titleLarge: serif(base.titleLarge, weight: FontWeight.w600, size: 24),
    titleMedium: serif(base.titleMedium, weight: FontWeight.w600, size: 20),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: RitualColors.line),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: RitualColors.line),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF5C554A)),
      ),
    ),
  );
}

/// Runder Emoji-Badge, wird in Katalog und Heute-Ansicht genutzt.
class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.emoji, {super.key, this.size = 48});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
