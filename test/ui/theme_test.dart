import 'dart:io';

import 'package:challenges/ui/app.dart';
import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

void main() {
  group('Ritual-Farbwelt', () {
    final theme = buildTheme();
    final scheme = theme.colorScheme;

    test('Farben aus der Vorlage', () {
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, const Color(0xFF0F0E0C));
      expect(scheme.primary, const Color(0xFFC9A96E));
      expect(scheme.onSurface, const Color(0xFFEFE8DC));
      expect(scheme.outlineVariant, const Color(0xFF2A2722));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0E0C));
    });

    test('Kontrast Text/Hintergrund mindestens 4.5:1', () {
      for (final (fg, bg, name) in [
        (scheme.onSurface, scheme.surface, 'Text'),
        (scheme.onSurfaceVariant, scheme.surface, 'Nebentext'),
        (scheme.primary, scheme.surface, 'Gold'),
        (scheme.onPrimary, scheme.primary, 'Text auf Gold'),
        (scheme.onSurface, scheme.surfaceContainerLow, 'Text auf Karte'),
      ]) {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
      }
    });

    test('Überschriften in Cormorant Garamond', () {
      for (final style in [
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
      ]) {
        expect(style?.fontFamily, ritualSerif);
      }
    });

    test('Schrift ist eingebunden', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $ritualSerif'));
      for (final f in [
        'CormorantGaramond-Regular.ttf',
        'CormorantGaramond-SemiBold.ttf',
        'CormorantGaramond-Italic.ttf',
      ]) {
        expect(File('assets/fonts/$f').existsSync(), isTrue, reason: f);
      }
    });
  });

  testWidgets('App nutzt immer das dunkle Ritual-Theme', (tester) async {
    await tester.pumpWidget(ChallengesApp(repository: FakeChallengeRepository()));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.colorScheme.primary, const Color(0xFFC9A96E));
    expect(app.title, 'Ritual');
  });
}
