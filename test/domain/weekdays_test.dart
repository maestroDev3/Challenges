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

  group('upcomingReminders', () {
    test('täglich: konkrete Termine ab heute', () {
      final list = upcomingReminders(running(const DailyKind()), now);
      expect(list.take(3), [
        DateTime(2026, 10, 7, 18),
        DateTime(2026, 10, 8, 18),
        DateTime(2026, 10, 9, 18),
      ]);
      expect(list, hasLength(maxUpcomingReminders));
    });

    test('pausierte Tage erzeugen keinen Termin – auch nicht heute (#72)', () {
      final c = running(const DailyKind())
          .pause(from: day(2), until: day(3)); // Mi–Do
      expect(upcomingReminders(c, now).first, DateTime(2026, 10, 9, 18));
    });

    test('Wochentage: nur an geplanten Tagen, Pausen übersprungen', () {
      final c = running(const WeeklyGoalKind(3,
          unit: WeeklyUnit.times, weekdays: {1, 3, 5}));
      expect(upcomingReminders(c, now).take(4), [
        DateTime(2026, 10, 7, 18),
        DateTime(2026, 10, 9, 18),
        DateTime(2026, 10, 12, 18),
        DateTime(2026, 10, 14, 18),
      ]);
      final paused = c.pause(from: day(2), until: day(4));
      expect(upcomingReminders(paused, now).first, DateTime(2026, 10, 12, 18));
    });

    test('flexibel: täglich, solange das Wochenziel offen ist', () {
      var c = running(const WeeklyGoalKind(3, unit: WeeklyUnit.times));
      c = c.checkIn(day(0), CheckInStatus.done);
      expect(upcomingReminders(c, now).first, DateTime(2026, 10, 7, 18));
      for (final d in [1, 2]) {
        c = c.checkIn(day(d), CheckInStatus.done);
      }
      expect(upcomingReminders(c, now).first, DateTime(2026, 10, 12, 18));
    });

    test('Wochenziel in Minuten verhält sich flexibel', () {
      final c = ActiveChallenge(
        id: 'n',
        template: templateById('nature-2h')!,
        startedOn: monday,
        reminder: const ReminderTime(18, 0),
      ).checkIn(day(1), CheckInStatus.done, minutes: 120);
      expect(upcomingReminders(c, now).first, DateTime(2026, 10, 12, 18));
    });

    test('einmalig: genau ein Termin; archiviert: keiner', () {
      final once = ActiveChallenge(
        id: 'o',
        template: ChallengeTemplate.custom(
            title: 'Schweigen',
            kind: OneTimeKind(const Duration(hours: 24),
                date: DateTime(2026, 10, 10))),
        startedOn: monday,
        reminder: const ReminderTime(8, 0),
      );
      expect(upcomingReminders(once, now), [DateTime(2026, 10, 10, 8)]);
      expect(upcomingReminders(running(const DailyKind()).finish(now), now),
          isEmpty);
    });
  });
}
