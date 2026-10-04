import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/week_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// Montag, 28.09.2026 – die betrachtete Woche geht bis Sonntag, 04.10.
final monday = DateTime(2026, 9, 28);
DateTime day(int offset) => monday.add(Duration(days: offset));
final sunday = day(6);

ActiveChallenge daily({
  String id = 'meditate-sleep',
  int startOffset = 0,
  Iterable<int> done = const [],
  Iterable<int> missed = const [],
  StreakRule rule = StreakRule.relaxed,
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

ActiveChallenge sportTimes({int target = 3, Iterable<int> done = const []}) {
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

ActiveChallenge natureMinutes(Map<int, int> minutesByDay) {
  var c = ActiveChallenge(
    id: 'nature',
    template: templateById('nature-2h')!,
    startedOn: day(-7),
    reminder: const ReminderTime(18, 0),
  );
  for (final e in minutesByDay.entries) {
    c = c.checkIn(day(e.key), CheckInStatus.done, minutes: e.value);
  }
  return c;
}

void main() {
  group('weekStartOf', () {
    test('liefert den Montag der Woche', () {
      expect(weekStartOf(day(3)), dayOf(monday));
      expect(weekStartOf(sunday), dayOf(monday));
      expect(weekStartOf(monday), dayOf(monday));
    });
  });

  group('reviewWeekFor', () {
    test('sonntags die laufende Woche, sonst die vergangene', () {
      expect(reviewWeekFor(sunday), dayOf(monday));
      expect(reviewWeekFor(day(7)), dayOf(monday));
      expect(reviewWeekFor(day(10)), dayOf(monday));
      expect(reviewWeekFor(day(13)), dayOf(day(7)));
    });
  });

  group('WeekReview.of', () {
    test('tägliche Challenge mit 6 von 7 Tagen: done 6, due 7, rate 6/7', () {
      final c = daily(done: [0, 1, 2, 3, 4, 5], missed: [6]);
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.doneDays, 6);
      expect(r.entries.single.dueDays, 7);
      expect(r.entries.single.missedDays, 1);
      expect(r.done, 6);
      expect(r.due, 7);
      expect(r.rate, closeTo(6 / 7, 1e-9));
    });

    test('Tage vor dem Start zählen nicht als fällig', () {
      final c = daily(startOffset: 3, done: [3, 4, 5, 6]);
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      expect(r.entries.single.dueDays, 4);
      expect(r.entries.single.doneDays, 4);
      expect(r.rate, 1.0);
    });

    test('pausierte Tage zählen nicht als fällig', () {
      final c = daily(done: [0, 1, 4, 5, 6]).pause(from: day(2), until: day(3));
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      expect(r.entries.single.dueDays, 5);
      expect(r.entries.single.days[2], DayStatus.paused);
      expect(r.rate, 1.0);
    });

    test('Tage nach heute zählen nicht als fällig (Woche läuft noch)', () {
      final c = daily(done: [0, 1, 2]);
      final r = WeekReview.of([c], weekStart: monday, today: day(3));
      expect(r.entries.single.dueDays, 4);
      expect(r.entries.single.doneDays, 3);
      expect(r.entries.single.days[3], DayStatus.open);
      expect(r.entries.single.days[4], DayStatus.open);
    });

    test('ein vergangener Tag ohne Eintrag gilt als verpasst', () {
      final c = daily(done: [0, 2]);
      final r = WeekReview.of([c], weekStart: monday, today: day(2));
      expect(r.entries.single.days[1], DayStatus.missed);
      expect(r.entries.single.missedDays, 1);
    });

    test('ein durch Joker geretteter Tag zählt als Joker, nicht als verpasst',
        () {
      // 7 Tage am Stück vor der Woche → ein Joker; Tag 2 der Woche verpasst.
      final c = daily(
        startOffset: -7,
        rule: StreakRule.joker,
        done: [-7, -6, -5, -4, -3, -2, -1, 0, 1, 3, 4, 5, 6],
        missed: [2],
      );
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      final e = r.entries.single;
      expect(e.jokerDays, 1);
      expect(e.missedDays, 0);
      expect(e.doneDays, 6);
      expect(e.days[2], DayStatus.joker);
    });

    test('Wochenziel „3-mal“ mit 2 Einheiten: due 3, done 2, nicht erreicht',
        () {
      final c = sportTimes(done: [1, 4]);
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      final e = r.entries.single;
      expect(e.dueDays, 3);
      expect(e.doneDays, 2);
      expect(e.weeklyGoalReached, isFalse);
      expect(r.rate, closeTo(2 / 3, 1e-9));
    });

    test('Wochenziel übererfüllt zählt höchstens das Ziel', () {
      final c = sportTimes(done: [0, 1, 2, 3, 4]);
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      expect(r.entries.single.doneDays, 3);
      expect(r.entries.single.weeklyGoalReached, isTrue);
      expect(r.rate, 1.0);
    });

    test('Minuten aus Wochenzielen werden je Challenge und gesamt summiert',
        () {
      final nature = natureMinutes({1: 40, 3: 70});
      final sport = sportTimes(done: [2]);
      final r =
          WeekReview.of([nature, sport], weekStart: monday, today: sunday);
      final natureEntry =
          r.entries.firstWhere((e) => e.challenge.id == 'nature');
      expect(natureEntry.minutes, 110);
      expect(r.totalMinutes, 110);
    });

    test('Minuten außerhalb der Woche zählen nicht', () {
      final nature = natureMinutes({-2: 60, 1: 40, 8: 30});
      final r = WeekReview.of([nature], weekStart: monday, today: day(10));
      expect(r.totalMinutes, 40);
    });

    test('ein in der Woche erreichter Meilenstein steht in badges', () {
      // Serie startet Freitag der Vorwoche: Tag 7 der Serie ist Donnerstag.
      final c = daily(
        startOffset: -3,
        done: [-3, -2, -1, 0, 1, 2, 3, 4, 5, 6],
      );
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      expect(r.badges, hasLength(1));
      expect(r.badges.single.milestone, 7);
      expect(r.badges.single.challenge.id, c.id);
    });

    test('ein früher erreichter Meilenstein steht nicht in badges', () {
      final c = daily(
        startOffset: -10,
        done: [for (var d = -10; d <= 6; d++) d],
      );
      final r = WeekReview.of([c], weekStart: monday, today: sunday);
      // Tag 7 war vor der Woche, Tag 21 ist noch nicht erreicht.
      expect(r.badges, isEmpty);
    });

    test('bestStreak ist die höchste aktuelle Serie am Ende der Woche', () {
      final a = daily(
        id: 'meditate-sleep',
        startOffset: -5,
        done: [for (var d = -5; d <= 6; d++) d],
      );
      final b = daily(id: 'eye-gaze', done: [0, 1, 2, 3, 4, 5, 6]);
      final r = WeekReview.of([a, b], weekStart: monday, today: sunday);
      expect(r.bestStreak, 12);
    });

    test('ohne Challenges: rate null, Summen 0, keine Einträge', () {
      final r = WeekReview.of([], weekStart: monday, today: sunday);
      expect(r.entries, isEmpty);
      expect(r.rate, isNull);
      expect(r.done, 0);
      expect(r.due, 0);
      expect(r.totalMinutes, 0);
      expect(r.badges, isEmpty);
      expect(r.bestStreak, 0);
    });

    test('einmalige Challenges erscheinen nicht', () {
      final once = ActiveChallenge(
        id: 'once',
        template: templateById('fasting-24h')!,
        startedOn: day(0),
        reminder: const ReminderTime(7, 0),
      ).checkIn(day(1), CheckInStatus.done);
      final r = WeekReview.of([once], weekStart: monday, today: sunday);
      expect(r.entries, isEmpty);
    });

    test('Challenges, die erst nach der Woche starten, erscheinen nicht', () {
      final c = daily(startOffset: 9);
      final r = WeekReview.of([c], weekStart: monday, today: day(10));
      expect(r.entries, isEmpty);
    });

    test('from ist der Montag, until der Sonntag', () {
      final r = WeekReview.of([], weekStart: day(3), today: sunday);
      expect(r.from, dayOf(monday));
      expect(r.until, dayOf(sunday));
    });
  });
}
