import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/domain/streak_warning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';

/// Montag, 5.10.2026; Sonntag ist der 11.10.
final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));
final morning = DateTime(2026, 10, 8, 10, 0); // Donnerstag
final lateEvening = DateTime(2026, 10, 8, 22, 0);
final today = day(3); // Donnerstag

ActiveChallenge daily({
  String id = 'meditate-sleep',
  Iterable<int> done = const [],
  Iterable<int> missed = const [],
  StreakRule rule = StreakRule.relaxed,
  int startOffset = -7,
}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: day(startOffset),
    reminder: const ReminderTime(7, 0),
    rule: rule,
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  for (final d in missed) {
    c = c.checkIn(day(d), CheckInStatus.missed);
  }
  return c;
}

ActiveChallenge sport(Iterable<int> done, {int target = 3}) {
  var c = ActiveChallenge(
    id: 'sport',
    template: ChallengeTemplate.custom(
      id: 'custom-sport',
      title: 'Sport',
      kind: WeeklyGoalKind(target, unit: WeeklyUnit.times),
    ),
    startedOn: day(-7),
    reminder: const ReminderTime(18, 0),
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('AppSettings Warnung', () {
    test('Standard: an, 21:00; alte Einstellungen laden mit Standard', () {
      const s = AppSettings();
      expect(s.streakWarningEnabled, isTrue);
      expect(s.streakWarningTime, const ReminderTime(21, 0));
      final loaded = decodeSettings('{"name":"Mia"}');
      expect(loaded.streakWarningEnabled, isTrue);
      expect(loaded.streakWarningTime, const ReminderTime(21, 0));
    });

    test('Codec rund', () {
      final s = const AppSettings().copyWith(
        streakWarningEnabled: false,
        streakWarningTime: const ReminderTime(20, 15),
      );
      expect(decodeSettings(encodeSettings(s)), s);
    });
  });

  group('streakWarningFor', () {
    test('Serie 3, heute offen → Warnung mit streak 3; Serie 2 → null', () {
      final three = daily(done: [0, 1, 2]);
      final w = streakWarningFor(three, today);
      expect(w?.streak, 3);
      expect(w?.jokerAvailable, isFalse);
      expect(streakWarningFor(daily(done: [1, 2]), today), isNull);
    });

    test('heute abgehakt (erledigt oder verpasst) → null', () {
      expect(streakWarningFor(daily(done: [0, 1, 2, 3]), today), isNull);
      expect(
          streakWarningFor(daily(done: [0, 1, 2], missed: [3]), today), isNull);
    });

    test('pausiert, vor dem Start oder archiviert → null', () {
      final c = daily(done: [0, 1, 2]);
      expect(streakWarningFor(c.pause(from: day(3), until: day(4)), today),
          isNull);
      expect(streakWarningFor(daily(startOffset: 5), today), isNull);
      expect(streakWarningFor(c.finish(today), today), isNull);
    });

    test('Regel Joker mit verfügbarem Joker → jokerAvailable', () {
      final c = daily(
        rule: StreakRule.joker,
        done: [-7, -6, -5, -4, -3, -2, -1, 0, 1, 2],
      );
      final w = streakWarningFor(c, today);
      expect(w?.streak, 10);
      expect(w?.jokerAvailable, isTrue);
    });

    test('Wochenziel: sonntags bei offenem Ziel, sonst null', () {
      final two = sport([0, 2]);
      expect(streakWarningFor(two, today), isNull);
      final sunday = streakWarningFor(two, day(6));
      expect(sunday?.weeklyDone, 2);
      expect(sunday?.weeklyTarget, 3);
      expect(streakWarningFor(sport([0, 2, 4]), day(6)), isNull);
    });

    test('einmalige Challenges → null', () {
      final once = ActiveChallenge(
        id: 'once',
        template: templateById('fasting-24h')!,
        startedOn: day(0),
        reminder: const ReminderTime(7, 0),
      );
      expect(streakWarningFor(once, today), isNull);
    });
  });

  group('upcomingStreakWarnings', () {
    const settings = AppSettings();

    test('morgens: heute 21:00; spät abends: nichts', () {
      final c = daily(done: [0, 1, 2]);
      expect(upcomingStreakWarnings(c, morning, settings),
          [DateTime(2026, 10, 8, 21, 0)]);
      expect(upcomingStreakWarnings(c, lateEvening, settings), isEmpty);
    });

    test('heute erledigt: morgen 21:00', () {
      final c = daily(done: [0, 1, 2, 3]);
      expect(upcomingStreakWarnings(c, morning, settings),
          [DateTime(2026, 10, 9, 21, 0)]);
    });

    test('eigene Uhrzeit und ausgeschaltet', () {
      final c = daily(done: [0, 1, 2]);
      final custom =
          settings.copyWith(streakWarningTime: const ReminderTime(20, 30));
      expect(upcomingStreakWarnings(c, morning, custom),
          [DateTime(2026, 10, 8, 20, 30)]);
      final off = settings.copyWith(streakWarningEnabled: false);
      expect(upcomingStreakWarnings(c, morning, off), isEmpty);
    });

    test('Serie 2: nichts', () {
      expect(upcomingStreakWarnings(daily(done: [1, 2]), morning, settings),
          isEmpty);
    });
  });

  group('openStreaks', () {
    test('liefert alle offenen Serien ab 3 Tagen', () {
      final a = daily(done: [0, 1, 2]);
      final b = daily(id: 'eye-gaze', done: [1, 2]);
      final c = daily(id: 'no-sugar', startOffset: 0, done: [0, 1, 2, 3]);
      final open = openStreaks([a, b, c], today);
      expect(open.map((w) => w.challenge.id), ['meditate-sleep']);
    });
  });

  group('syncStreakWarnings', () {
    test('plant für offene Serien und löscht für erledigte', () async {
      final open = daily(done: [0, 1, 2]);
      final done = daily(id: 'eye-gaze', done: [0, 1, 2, 3]);
      final repo = FakeChallengeRepository(initial: [open, done]);
      final scheduler = FakeReminderScheduler();
      await syncStreakWarnings(repo, scheduler,
          now: morning, settings: const AppSettings());
      expect(scheduler.streakWarnings['meditate-sleep'],
          [DateTime(2026, 10, 8, 21, 0)]);
      expect(scheduler.streakWarnings['eye-gaze'],
          [DateTime(2026, 10, 9, 21, 0)]);
    });

    test('ausgeschaltet: alle Warnungen gelöscht', () async {
      final repo = FakeChallengeRepository(initial: [daily(done: [0, 1, 2])]);
      final scheduler = FakeReminderScheduler()
        ..streakWarnings['meditate-sleep'] = [DateTime(2026, 10, 8, 21, 0)];
      await syncStreakWarnings(repo, scheduler,
          now: morning,
          settings: const AppSettings().copyWith(streakWarningEnabled: false));
      expect(scheduler.streakWarnings, isEmpty);
      expect(scheduler.streakWarningsCancelled, ['meditate-sleep']);
    });

    test('syncReminders mit Einstellungen plant die Warnungen mit', () async {
      final repo = FakeChallengeRepository(initial: [daily(done: [0, 1, 2])]);
      final scheduler = FakeReminderScheduler();
      await syncReminders(repo, scheduler,
          now: morning, settings: const AppSettings());
      expect(scheduler.streakWarnings['meditate-sleep'], isNotEmpty);
    });
  });
}
