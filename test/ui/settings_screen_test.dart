import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:challenges/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backup_files.dart';
import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 5, 20, 15);

Future<void> pumpSettings(
  WidgetTester tester,
  FakeSettingsRepository settings, {
  TimeOfDay? picked,
}) =>
    tester.pumpApp(SettingsScreen(
      settings: settings,
      repository: FakeChallengeRepository(),
      backupFiles: FakeBackupFiles(),
      clock: () => now,
      pickTime: (_, _) async => picked,
    ));

void main() {
  testWidgets('das Zahnrad im Profil öffnet die Einstellungen', (tester) async {
    await tester.pumpApp(HomeShell(
      repository: FakeChallengeRepository(),
      settings: FakeSettingsRepository(),
      backupFiles: FakeBackupFiles(),
      clock: () => now,
    ));
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('Uhrzeit für neue Challenges'), findsOneWidget);
  });

  testWidgets('Name lässt sich ändern und wird gespeichert', (tester) async {
    final settings = FakeSettingsRepository();
    await pumpSettings(tester, settings);
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Mia ');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(settings.current.name, 'Mia');
    expect(find.text('Mia'), findsOneWidget);
  });

  testWidgets('Standard-Erinnerung wählen und zurücksetzen', (tester) async {
    final settings = FakeSettingsRepository();
    await pumpSettings(tester, settings,
        picked: const TimeOfDay(hour: 6, minute: 30));
    expect(find.text('Je nach Challenge'), findsOneWidget);
    expect(find.textContaining('Laufende Challenges behalten ihre Uhrzeit'),
        findsOneWidget);

    await tester.tap(find.text('Uhrzeit für neue Challenges'));
    await tester.pumpAndSettle();
    expect(settings.current.defaultReminder, const ReminderTime(6, 30));
    expect(find.text('06:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(settings.current.defaultReminder, isNull);
    expect(find.text('Je nach Challenge'), findsOneWidget);
  });

  testWidgets('Abbruch der Uhrzeitwahl ändert nichts', (tester) async {
    final settings = FakeSettingsRepository();
    await pumpSettings(tester, settings);
    await tester.tap(find.text('Uhrzeit für neue Challenges'));
    await tester.pumpAndSettle();
    expect(settings.current.defaultReminder, isNull);
  });

  testWidgets('Schalter „Intro beim Start zeigen“ wird gespeichert',
      (tester) async {
    final settings = FakeSettingsRepository();
    await pumpSettings(tester, settings);
    await tester.tap(find.text('Intro beim Start zeigen'));
    await tester.pumpAndSettle();
    expect(settings.current.showIntro, isFalse);
  });

  testWidgets('„Daten sichern“ öffnet die Seite zum Sichern', (tester) async {
    await pumpSettings(tester, FakeSettingsRepository());
    await tester.tap(find.text('Daten sichern'));
    await tester.pumpAndSettle();
    expect(find.text('Backup speichern'), findsOneWidget);
  });

  testWidgets('Sprachwechsel plant die Erinnerungen mit neuem Text neu',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      ActiveChallenge(
        id: 'wake',
        template: templateById('wake-5am')!,
        startedOn: DateTime(2026, 10, 1),
        reminder: const ReminderTime(5, 0),
      ),
    ]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(SettingsScreen(
      settings: FakeSettingsRepository(),
      repository: repo,
      scheduler: scheduler,
      clock: () => now,
    ));
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(scheduler.scheduled, {'wake'});
  });
}
