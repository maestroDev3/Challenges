import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/statistics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Heute: Dienstag, 20.10.2026. Oktober begann an einem Donnerstag.
final today = DateTime(2026, 10, 20);
DateTime d(int year, int month, int day) => DateTime(year, month, day);

ActiveChallenge daily(
  String id, {
  required DateTime start,
  Iterable<DateTime> done = const [],
  Iterable<DateTime> missed = const [],
  ChallengeStatus status = ChallengeStatus.active,
  DateTime? finishedOn,
}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: start,
    reminder: const ReminderTime(7, 0),
  );
  for (final x in done) {
    c = c.checkIn(x, CheckInStatus.done);
  }
  for (final x in missed) {
    c = c.checkIn(x, CheckInStatus.missed);
  }
  return c.copyWith(status: status, finishedOn: finishedOn);
}

ActiveChallenge weeklyTimes(int target, Iterable<DateTime> done,
    {DateTime? start}) {
  var c = ActiveChallenge(
    id: 'sport',
    template: ChallengeTemplate.custom(
      id: 'custom-sport',
      title: 'Sport',
      kind: WeeklyGoalKind(target, unit: WeeklyUnit.times),
    ),
    startedOn: start ?? d(2026, 9, 28),
    reminder: const ReminderTime(18, 0),
  );
  for (final x in done) {
    c = c.checkIn(x, CheckInStatus.done);
  }
  return c;
}

ActiveChallenge nature(Map<DateTime, int> minutes) {
  var c = ActiveChallenge(
    id: 'nature',
    template: templateById('nature-2h')!,
    startedOn: d(2026, 9, 1),
    reminder: const ReminderTime(18, 0),
  );
  for (final e in minutes.entries) {
    c = c.checkIn(e.key, CheckInStatus.done, minutes: e.value);
  }
  return c;
}

Iterable<DateTime> range(DateTime from, DateTime to) sync* {
  for (var x = from; !x.isAfter(to); x = x.add(const Duration(days: 1))) {
    yield x;
  }
}

Statistics month(List<ActiveChallenge> all) =>
    Statistics.of(all, today: today, period: StatsPeriod.month);

void main() {
  group('Statistics.of – Zähler', () {
    test('daysDone zählt erledigte Tage im Zeitraum, außerhalb nicht', () {
      final c = daily('meditate-sleep',
          start: d(2026, 9, 25),
          done: [...range(d(2026, 9, 25), d(2026, 9, 30)), d(2026, 10, 2)]);
      expect(month([c]).daysDone, 1);
      expect(
        Statistics.of([c], today: today, period: StatsPeriod.year).daysDone,
        7,
      );
    });

    test('daysDone zählt auch einmalige Challenges', () {
      final once = ActiveChallenge(
        id: 'once',
        template: templateById('fasting-24h')!,
        startedOn: d(2026, 10, 3),
        reminder: const ReminderTime(7, 0),
      ).checkIn(d(2026, 10, 3), CheckInStatus.done);
      final s = month([once]);
      expect(s.daysDone, 1);
      expect(s.rate, isNull);
    });

    test('longestStreak ist die beste Serie über alle, auch im Archiv', () {
      final a = daily('meditate-sleep',
          start: d(2026, 10, 10),
          done: range(d(2026, 10, 10), d(2026, 10, 14)));
      final old = daily('no-sugar',
          start: d(2026, 8, 1),
          done: range(d(2026, 8, 1), d(2026, 8, 12)),
          status: ChallengeStatus.ended,
          finishedOn: d(2026, 8, 20));
      final s = month([a, old]);
      expect(s.longestStreak, 12);
      expect(s.longestStreakChallenge?.id, 'no-sugar');
    });

    test('active und completed zählen laufende und geschaffte Challenges',
        () {
      final a = daily('meditate-sleep', start: d(2026, 10, 1));
      final b = daily('eye-gaze', start: d(2026, 10, 1));
      final won = daily('no-sugar',
          start: d(2026, 9, 1),
          status: ChallengeStatus.completed,
          finishedOn: d(2026, 9, 22));
      final lost = daily('wake-5am',
          start: d(2026, 9, 1),
          status: ChallengeStatus.ended,
          finishedOn: d(2026, 9, 5));
      final s = month([a, b, won, lost]);
      expect(s.active, 2);
      expect(s.completed, 1);
    });
  });

  group('Statistics.of – Quote', () {
    test('erledigt / fällig im Zeitraum; heute ohne Eintrag zählt nicht', () {
      // 1.–19.10. = 19 fällige Tage, 16 erledigt, 3 verpasst; heute offen.
      final c = daily('meditate-sleep',
          start: d(2026, 10, 1),
          done: range(d(2026, 10, 1), d(2026, 10, 16)),
          missed: range(d(2026, 10, 17), d(2026, 10, 19)));
      final s = month([c]);
      expect(s.done, 16);
      expect(s.due, 19);
      expect(s.rate, closeTo(16 / 19, 1e-9));
    });

    test('Wochenziel in Einheiten: 3 von 3, 2 von 3, übererfüllt 3 von 3',
        () {
      // Woche 5.–11.10.: 3×, Woche 12.–18.10.: 2×, laufende Woche: 5×
      final c = weeklyTimes(3, [
        d(2026, 10, 5), d(2026, 10, 7), d(2026, 10, 9), //
        d(2026, 10, 13), d(2026, 10, 15), //
        d(2026, 10, 19), d(2026, 10, 20),
      ]);
      final s = month([c]);
      // Woche 28.9.–4.10. endet im Oktober und zählt mit 0 von 3.
      expect(s.due, 12);
      expect(s.done, 3 + 2 + 2);
      final overdone = weeklyTimes(3, range(d(2026, 10, 5), d(2026, 10, 9)));
      final s2 = Statistics.of([overdone],
          today: d(2026, 10, 11), period: StatsPeriod.month);
      expect(s2.done, 3);
      expect(s2.due, 6);
    });

    test('rate ist null, wenn im Zeitraum nichts fällig war', () {
      final c = daily('meditate-sleep',
          start: d(2026, 8, 1),
          done: range(d(2026, 8, 1), d(2026, 8, 10)),
          status: ChallengeStatus.ended,
          finishedOn: d(2026, 8, 10));
      expect(month([c]).rate, isNull);
      expect(month([]).rate, isNull);
    });
  });

  group('Statistics.of – Heatmap und Wochen', () {
    test('Heatmap reicht mindestens 13 Wochen zurück und endet heute', () {
      final c = daily('meditate-sleep', start: d(2026, 10, 1));
      final s = month([c]);
      expect(s.heatmap.length, 13 * 7 - 5); // Mo 27.7. … Di 20.10.
      expect(s.heatmapStart, DateTime.utc(2026, 7, 27));
      expect(s.heatmap.last, isNull); // heute ohne Eintrag: nichts fällig
    });

    test('Heatmap beginnt beim Montag der Woche des ersten Starts', () {
      final c = daily('meditate-sleep', start: d(2026, 3, 11)); // Mittwoch
      final s = month([c]);
      expect(s.heatmapStart, DateTime.utc(2026, 3, 9));
      expect(s.heatmap.length, 33 * 7 - 5);
    });

    test('Heatmap reicht höchstens 52 Wochen zurück', () {
      final c = daily('meditate-sleep', start: d(2024, 1, 1));
      final s = month([c]);
      expect(s.heatmap.length, 52 * 7 - 5);
      expect(s.weeks.length, 52);
    });

    test('ein Tag mit 1 von 2 fälligen Challenges hat 0,5, ohne fällige null',
        () {
      final a = daily('meditate-sleep',
          start: d(2026, 10, 1),
          done: [d(2026, 10, 1)],
          missed: [d(2026, 10, 2)]);
      final b = daily('eye-gaze',
          start: d(2026, 10, 1), done: [d(2026, 10, 1), d(2026, 10, 2)]);
      final s = month([a, b]);
      double? at(DateTime day) =>
          s.heatmap[dayOf(day).difference(s.heatmapStart).inDays];
      expect(at(d(2026, 10, 1)), 1.0);
      expect(at(d(2026, 10, 2)), 0.5);
      expect(at(d(2026, 9, 30)), isNull);
    });

    test('weeks deckt dieselben Wochen ab, zuletzt die laufende', () {
      final c = daily('meditate-sleep', start: d(2026, 10, 1));
      final s = month([c]);
      expect(s.weeks.length, 13);
      expect(s.weeks.first.from, s.heatmapStart);
      expect(s.weeks.last.from, DateTime.utc(2026, 10, 19));
    });
  });

  group('Statistics.of – Wochentage', () {
    test('Quote je Wochentag, bester und schwächster Tag', () {
      // Oktober: Dienstage 6., 13. erledigt; Sonntage 4., 11., 18. verpasst.
      final c = daily('meditate-sleep',
          start: d(2026, 10, 1),
          done: [
            for (final x in range(d(2026, 10, 1), d(2026, 10, 19)))
              if (x.weekday != DateTime.sunday) x,
          ],
          missed: [d(2026, 10, 4), d(2026, 10, 11), d(2026, 10, 18)]);
      final s = month([c]);
      expect(s.weekdays[DateTime.tuesday - 1], 1.0);
      expect(s.weekdays[DateTime.sunday - 1], 0.0);
      expect(s.bestWeekday, isNot(DateTime.sunday));
      expect(s.worstWeekday, DateTime.sunday);
    });

    test('ein Wochentag ohne fällige Tage ist null', () {
      final c = daily('meditate-sleep',
          start: d(2026, 10, 19), done: [d(2026, 10, 19)]);
      final s = month([c]);
      expect(s.weekdays[DateTime.monday - 1], 1.0);
      expect(s.weekdays[DateTime.friday - 1], isNull);
      expect(s.bestWeekday, DateTime.monday);
      expect(s.worstWeekday, DateTime.monday);
    });
  });

  group('Statistics.of – Zeit und Listen', () {
    test('Minuten je Wochenziel-Challenge im Zeitraum und gesamt', () {
      final n = nature(
          {d(2026, 9, 29): 60, d(2026, 10, 2): 40, d(2026, 10, 9): 70});
      final s = month([n]);
      expect(s.minutesByChallenge.single.challenge.id, 'nature');
      expect(s.minutesByChallenge.single.minutes, 110);
      expect(s.totalMinutes, 110);
    });

    test('perChallenge listet laufende Challenges mit Serie und Quote', () {
      final a = daily('meditate-sleep',
          start: d(2026, 10, 14),
          done: range(d(2026, 10, 14), d(2026, 10, 20)));
      final old = daily('no-sugar',
          start: d(2026, 8, 1),
          status: ChallengeStatus.ended,
          finishedOn: d(2026, 8, 10));
      final s = month([a, old]);
      expect(s.perChallenge, hasLength(1));
      expect(s.perChallenge.single.challenge.id, 'meditate-sleep');
      expect(s.perChallenge.single.currentStreak, 7);
      expect(s.perChallenge.single.rate, 1.0);
    });

    test('badges nennt alle Abzeichen mit Challenge', () {
      final a = daily('meditate-sleep',
          start: d(2026, 9, 1), done: range(d(2026, 9, 1), d(2026, 9, 22)));
      final s = month([a]);
      expect(s.badges.map((b) => b.milestone), [7, 21]);
      expect(s.badges.first.challenge.id, 'meditate-sleep');
    });

    test('ohne Challenges: Zähler 0, rate null, Listen leer', () {
      final s = month([]);
      expect(s.daysDone, 0);
      expect(s.longestStreak, 0);
      expect(s.longestStreakChallenge, isNull);
      expect(s.active, 0);
      expect(s.completed, 0);
      expect(s.rate, isNull);
      expect(s.heatmap.length, 13 * 7 - 5);
      expect(s.heatmap.every((v) => v == null), isTrue);
      expect(s.weeks.length, 13);
      expect(s.weekdays.every((v) => v == null), isTrue);
      expect(s.bestWeekday, isNull);
      expect(s.minutesByChallenge, isEmpty);
      expect(s.totalMinutes, 0);
      expect(s.perChallenge, isEmpty);
      expect(s.badges, isEmpty);
    });
  });
}
