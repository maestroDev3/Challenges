import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/streak_warning.dart';
import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/l10n/background_texts.dart';
import 'package:challenges/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backup_files.dart';
import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

final de = lookupAppLocalizations(const Locale('de'));
final en = lookupAppLocalizations(const Locale('en'));
final ru = lookupAppLocalizations(const Locale('ru'));

/// Donnerstag, 8.10.2026, 10:00 – Serie 3 (5.–7.10.), heute offen.
final now = DateTime(2026, 10, 8, 10, 0);

ActiveChallenge openStreak({StreakRule rule = StreakRule.relaxed}) {
  var c = ActiveChallenge(
    id: 'meditate-sleep',
    template: templateById('meditate-sleep')!,
    startedOn: DateTime(2026, 9, 28),
    reminder: const ReminderTime(7, 0),
    rule: rule,
  );
  for (var d = 5; d <= 7; d++) {
    c = c.checkIn(DateTime(2026, 10, d), CheckInStatus.done);
  }
  return c;
}

Future<void> pumpSettings(
  WidgetTester tester,
  FakeSettingsRepository settings,
  FakeReminderScheduler scheduler, {
  TimeOfDay? picked,
}) =>
    tester.pumpApp(SettingsScreen(
      settings: settings,
      repository: FakeChallengeRepository(initial: [openStreak()]),
      backupFiles: FakeBackupFiles(),
      scheduler: scheduler,
      clock: () => now,
      pickTime: (_, _) async => picked,
    ));

void main() {
  group('streakWarningTexts', () {
    test('Serie 14 ohne Joker', () {
      final w = StreakWarning(
          challenge: openStreak(), streak: 14, jokerAvailable: false);
      final t = streakWarningTexts(de, w);
      expect(t.title, 'Deine 14-Tage-Serie endet um Mitternacht.');
      expect(t.body,
          'Meditieren vor dem Schlafen ist heute noch offen – jetzt abhaken.');
    });

    test('mit Joker', () {
      final w = StreakWarning(
          challenge: openStreak(), streak: 14, jokerAvailable: true);
      expect(streakWarningTexts(de, w).body,
          contains('Ein Joker würde sie retten.'));
    });

    test('Wochenziel', () {
      final sport = ActiveChallenge(
        id: 'sport',
        template: ChallengeTemplate.custom(
          id: 'custom-sport',
          title: 'Sport',
          kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times),
        ),
        startedOn: DateTime(2026, 9, 28),
        reminder: const ReminderTime(18, 0),
      );
      final w = StreakWarning(
        challenge: sport,
        streak: 0,
        jokerAvailable: false,
        weeklyDone: 2,
        weeklyTarget: 3,
      );
      final t = streakWarningTexts(de, w);
      expect(t.title, 'Sport: Wochenziel noch offen');
      expect(t.body, 'Bis Mitternacht: 2 von 3 geschafft.');
    });

    test('Englisch und Russisch', () {
      final w = StreakWarning(
          challenge: openStreak(), streak: 3, jokerAvailable: false);
      expect(streakWarningTexts(en, w).title,
          'Your 3-day streak ends at midnight.');
      expect(streakWarningTexts(ru, w).title,
          'Твоя серия из 3 дней закончится в полночь.');
    });
  });

  testWidgets('der Schalter „Warnung vor dem Serienende“ schaltet aus',
      (tester) async {
    final settings = FakeSettingsRepository();
    final scheduler = FakeReminderScheduler();
    await pumpSettings(tester, settings, scheduler);
    expect(find.text('Warnung vor dem Serienende'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    await tester.tap(find.text('Warnung vor dem Serienende'));
    await tester.pumpAndSettle();
    expect(settings.current.streakWarningEnabled, isFalse);
    expect(scheduler.streakWarningsCancelled, contains('meditate-sleep'));
    expect(find.text('21:00'), findsNothing);
  });

  testWidgets('die Uhrzeit der Warnung lässt sich ändern und plant neu',
      (tester) async {
    final settings = FakeSettingsRepository();
    final scheduler = FakeReminderScheduler();
    await pumpSettings(tester, settings, scheduler,
        picked: const TimeOfDay(hour: 20, minute: 30));
    await tester.tap(find.text('Uhrzeit der Warnung'));
    await tester.pumpAndSettle();
    expect(settings.current.streakWarningTime, const ReminderTime(20, 30));
    expect(find.text('20:30'), findsOneWidget);
    expect(scheduler.streakWarnings['meditate-sleep'],
        [DateTime(2026, 10, 8, 20, 30)]);
  });
}
