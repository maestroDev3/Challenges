import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

// Mittwoch, 7. Oktober 2026, 9:15
final now = DateTime(2026, 10, 7, 9, 15);
final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge running(ChallengeKind kind) => ActiveChallenge(
      id: 'x',
      template: ChallengeTemplate.custom(title: 'Laufen', kind: kind),
      startedOn: monday,
      reminder: const ReminderTime(18, 0),
    );

void main() {
  group('Wochentage', () {
    test('Anzahl ergibt sich aus den Tagen', () {
      final t = ChallengeTemplate.custom(
        title: 'Laufen',
        kind: const WeeklyGoalKind(1,
            unit: WeeklyUnit.times, weekdays: {1, 3, 5}),
      );
      final kind = t.kind as WeeklyGoalKind;
      expect(kind.target, 3);
      expect(kind.weekdays, {1, 3, 5});
      expect(t.kindLabel, '3×/Woche · Mo Mi Fr');
    });

    test('nur 1–7 und nur bei „Mal“', () {
      expect(
          () => ChallengeTemplate.custom(
              title: 'a',
              kind: const WeeklyGoalKind(1,
                  unit: WeeklyUnit.times, weekdays: {0})),
          throwsArgumentError);
      expect(
          () => ChallengeTemplate.custom(
              title: 'a', kind: const WeeklyGoalKind(60, weekdays: {1})),
          throwsArgumentError);
    });

    test('ein anderer Tag zählt trotzdem für die Woche', () {
      var c = running(const WeeklyGoalKind(3,
          unit: WeeklyUnit.times, weekdays: {1, 3, 5}));
      for (final d in [1, 3, 5]) {
        c = c.checkIn(day(d), CheckInStatus.done); // Di, Do, Sa
      }
      expect(c.progress(day(6)), 1.0);
    });
  });

  group('reminderPlan', () {
    test('täglich', () {
      final plan = reminderPlan(running(const DailyKind()), now);
      expect(plan, isA<DailyReminder>());
      expect((plan as DailyReminder).first, DateTime(2026, 10, 7, 18));
    });

    test('Wochentage: je Tag der nächste Termin, wöchentlich wiederholt', () {
      final plan = reminderPlan(
          running(const WeeklyGoalKind(3,
              unit: WeeklyUnit.times, weekdays: {1, 3, 5})),
          now);
      expect(plan, isA<WeekdayReminders>());
      expect((plan as WeekdayReminders).firsts, {
        1: DateTime(2026, 10, 12, 18),
        3: DateTime(2026, 10, 7, 18),
        5: DateTime(2026, 10, 9, 18),
      });
    });

    test('Wochentage: Pausen werden übersprungen', () {
      final c = running(const WeeklyGoalKind(3,
              unit: WeeklyUnit.times, weekdays: {1, 3, 5}))
          .pause(from: day(2), until: day(4));
      final plan = reminderPlan(c, now) as WeekdayReminders;
      expect(plan.firsts[3], DateTime(2026, 10, 14, 18));
      expect(plan.firsts[5], DateTime(2026, 10, 16, 18));
      expect(plan.firsts[1], DateTime(2026, 10, 12, 18));
    });

    test('flexibel: heute, solange das Wochenziel offen ist', () {
      var c = running(const WeeklyGoalKind(3, unit: WeeklyUnit.times));
      c = c.checkIn(day(0), CheckInStatus.done);
      final plan = reminderPlan(c, now);
      expect(plan, isA<OnceReminder>());
      expect((plan as OnceReminder).at, DateTime(2026, 10, 7, 18));
    });

    test('flexibel: Ziel erreicht → erst nächsten Montag', () {
      var c = running(const WeeklyGoalKind(3, unit: WeeklyUnit.times));
      for (final d in [0, 1, 2]) {
        c = c.checkIn(day(d), CheckInStatus.done);
      }
      expect((reminderPlan(c, now) as OnceReminder).at,
          DateTime(2026, 10, 12, 18));
    });

    test('Wochenziel in Minuten verhält sich flexibel', () {
      final c = ActiveChallenge(
        id: 'n',
        template: templateById('nature-2h')!,
        startedOn: monday,
        reminder: const ReminderTime(18, 0),
      ).checkIn(day(1), CheckInStatus.done, minutes: 120);
      expect((reminderPlan(c, now) as OnceReminder).at,
          DateTime(2026, 10, 12, 18));
    });

    test('einmalig und archiviert', () {
      final once = ActiveChallenge(
        id: 'o',
        template: ChallengeTemplate.custom(
            title: 'Schweigen',
            kind: OneTimeKind(const Duration(hours: 24),
                date: DateTime(2026, 10, 10))),
        startedOn: monday,
        reminder: const ReminderTime(8, 0),
      );
      expect((reminderPlan(once, now) as OnceReminder).at,
          DateTime(2026, 10, 10, 8));
      expect(reminderPlan(running(const DailyKind()).finish(now), now),
          isA<NoReminder>());
    });
  });
}
