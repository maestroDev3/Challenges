import 'package:flutter/material.dart';

/// Warmes Orange als einzige Akzentfarbe – passend zur Streak-Flamme.
const seedColor = Color(0xFFFF6B35);

ThemeData buildTheme(
  Brightness brightness, {
  DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
