import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/app.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/german_device.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 5, 20, 15);

void main() {
  group('defaultReminderFor', () {
    test('Vorlagen mit eigener Uhrzeit behalten sie', () {
      expect(defaultReminderFor('wake-5am', fallback: const ReminderTime(6, 30)),
          const ReminderTime(5, 0));
    });

    test('sonst gilt die Standard-Erinnerung, ohne sie 09:00', () {
      expect(defaultReminderFor('no-sugar', fallback: const ReminderTime(6, 30)),
          const ReminderTime(6, 30));
      expect(defaultReminderFor('no-sugar'), const ReminderTime(9, 0));
    });
  });

  testWidgets('Katalog: Standard-Erinnerung gilt nur ohne eigene Uhrzeit',
      (tester) async {
    await tester.pumpApp(
      CatalogScreen(
        repository: FakeChallengeRepository(),
        defaultReminder: const ReminderTime(6, 30),
      ),
      size: const Size(900, 3200),
    );
    await tester.tap(find.text('21 Tage ohne Zucker'));
    await tester.pumpAndSettle();
    expect(find.text('06:30'), findsOneWidget);

    Navigator.of(tester.element(find.text('06:30'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Um 5 Uhr aufstehen'));
    await tester.pumpAndSettle();
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('Editor startet mit der Standard-Erinnerung', (tester) async {
    await tester.pumpApp(ChallengeEditorScreen(
      repository: FakeChallengeRepository(),
      clock: () => now,
      defaultReminder: const ReminderTime(6, 30),
    ));
    expect(find.text('06:30'), findsOneWidget);
  });

  testWidgets('ohne Standard-Erinnerung bleibt der Editor bei 09:00',
      (tester) async {
    await tester.pumpApp(ChallengeEditorScreen(
      repository: FakeChallengeRepository(),
      clock: () => now,
    ));
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('die gespeicherte Standard-Erinnerung erreicht den Katalog',
      (tester) async {
    await tester.pumpApp(
      HomeShell(
        repository: FakeChallengeRepository(),
        settings: FakeSettingsRepository(
            const AppSettings(defaultReminder: ReminderTime(6, 30))),
        clock: () => now,
      ),
      size: const Size(900, 3200),
    );
    await tester.tap(find.text('Entdecken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21 Tage ohne Zucker'));
    await tester.pumpAndSettle();
    expect(find.text('06:30'), findsOneWidget);
  });

  testWidgets('ohne Intro startet die App direkt mit „Heute“', (tester) async {
    useGermanDevice(tester);
    await tester.pumpWidget(ChallengesApp(
      repository: FakeChallengeRepository(),
      showIntro: false,
    ));
    await tester.pump();
    expect(find.text('RITUAL'), findsNothing);
    expect(find.text('Heute'), findsWidgets);
  });
}
