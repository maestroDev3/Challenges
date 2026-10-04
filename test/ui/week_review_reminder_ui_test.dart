import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/app.dart';
import 'package:challenges/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backup_files.dart';
import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/fake_settings_repository.dart';
import '../support/german_device.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 4, 19, 5);

ActiveChallenge running() => ActiveChallenge(
      id: 'a',
      template: templateById('meditate-sleep')!,
      startedOn: DateTime(2026, 9, 28),
      reminder: const ReminderTime(7, 0),
    );

Future<void> pumpSettings(
  WidgetTester tester,
  FakeSettingsRepository settings, {
  TimeOfDay? picked,
  FakeReminderScheduler? scheduler,
}) =>
    tester.pumpApp(SettingsScreen(
      settings: settings,
      repository: FakeChallengeRepository(initial: [running()]),
      backupFiles: FakeBackupFiles(),
      scheduler: scheduler,
      clock: () => now,
      pickTime: (_, _) async => picked,
    ));

void main() {
  testWidgets('der Schalter „Wochenrückblick“ ändert die Einstellung',
      (tester) async {
    final settings = FakeSettingsRepository();
    final scheduler = FakeReminderScheduler();
    await pumpSettings(tester, settings, scheduler: scheduler);
    expect(find.text('Wochenrückblick am Sonntag'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);

    await tester.tap(find.text('Wochenrückblick am Sonntag'));
    await tester.pumpAndSettle();
    expect(settings.current.weekReviewEnabled, isFalse);
    expect(scheduler.weekReviewCancelled, 1);
    expect(find.text('19:00'), findsNothing);
  });

  testWidgets('die Uhrzeit des Wochenrückblicks lässt sich ändern',
      (tester) async {
    final settings = FakeSettingsRepository();
    final scheduler = FakeReminderScheduler();
    await pumpSettings(tester, settings,
        picked: const TimeOfDay(hour: 20, minute: 30), scheduler: scheduler);
    await tester.tap(find.text('Uhrzeit Wochenrückblick'));
    await tester.pumpAndSettle();
    expect(settings.current.weekReviewTime, const ReminderTime(20, 30));
    expect(find.text('20:30'), findsOneWidget);
    expect(scheduler.weekReviewAt, DateTime(2026, 10, 4, 20, 30));
  });

  testWidgets('die App öffnet den Rückblick, wenn sie per Benachrichtigung '
      'gestartet wurde', (tester) async {
    useGermanDevice(tester);
    await tester.pumpWidget(ChallengesApp(
      repository: FakeChallengeRepository(initial: [running()]),
      settings: FakeSettingsRepository(const AppSettings(showIntro: false)),
      showIntro: false,
      openWeekReview: true,
      clock: () => now,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Deine Woche'), findsOneWidget);
  });
}
