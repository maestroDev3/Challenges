import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/milestones.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String id) => ActiveChallenge(
      id: 'a',
      template: templateById(id)!,
      startedOn: day(0),
      reminder: const ReminderTime(7, 0),
    );

ActiveChallenge doneRange(ActiveChallenge c, int from, int to) {
  for (var d = from; d <= to; d++) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c;
}

void main() {
  test('Meilensteine sind 7, 21, 30, 66 und 100', () {
    expect(milestones, [7, 21, 30, 66, 100]);
  });

  group('milestoneReached', () {
    test('liefert den neuen Meilenstein genau einmal', () {
      final six = doneRange(start('meditate-sleep'), 0, 5);
      final seven = six.checkIn(day(6), CheckInStatus.done);
      final eight = seven.checkIn(day(7), CheckInStatus.done);
      expect(milestoneReached(six, seven), 7);
      expect(milestoneReached(seven, eight), isNull);
    });

    test('21 Tage', () {
      final before = doneRange(start('meditate-sleep'), 0, 19);
      final after = before.checkIn(day(20), CheckInStatus.done);
      expect(milestoneReached(before, after), 21);
    });

    test('bereits erreichter Meilenstein wird nicht erneut gefeiert', () {
      var c = doneRange(start('meditate-sleep'), 0, 9); // beste Streak 10
      c = c.checkIn(day(10), CheckInStatus.missed);
      final before = doneRange(c, 11, 16); // 6 Tage
      final after = before.checkIn(day(17), CheckInStatus.done); // 7
      expect(milestoneReached(before, after), isNull);
    });

    test('Nachtragen kann einen Meilenstein erreichen', () {
      final before = doneRange(start('meditate-sleep'), 0, 2);
      final withGap = doneRange(before, 4, 6); // Lücke an Tag 3
      final fixed = withGap.correct(day(3), CheckInStatus.done, today: day(6));
      expect(milestoneReached(withGap, fixed), 7);
    });
  });

  test('Abzeichen bleiben nach dem Abschließen erhalten', () {
    final c = doneRange(start('meditate-sleep'), 0, 22).finish(day(22));
    expect(badges(c), [7, 21]);
  });

  group('nextMilestone', () {
    test('bei Serie 7 (heute erledigt) ist 21 der nächste, in 14 Tagen', () {
      final c = doneRange(start('meditate-sleep'), 0, 6);
      final next = nextMilestone(c, day(6));
      expect(next?.days, 21);
      expect(next?.remaining, 14);
      expect(next?.date, dayOf(day(20)));
    });

    test('heute noch offen: der Marker fällt einen Tag früher', () {
      final c = doneRange(start('meditate-sleep'), 0, 6);
      final next = nextMilestone(c, day(7));
      expect(next?.remaining, 14);
      expect(next?.date, dayOf(day(20)));
    });

    test('bei Serie 0 ist 7 der nächste mit remaining 7', () {
      final next = nextMilestone(start('meditate-sleep'), day(0));
      expect(next?.days, 7);
      expect(next?.remaining, 7);
    });

    test('ab Serie 100 gibt es keinen weiteren', () {
      final c = doneRange(start('meditate-sleep'), 0, 99);
      expect(nextMilestone(c, day(99)), isNull);
    });

    test('einmalige und Wochenziel-Challenges haben keinen', () {
      expect(nextMilestone(start('fasting-24h'), day(0)), isNull);
      expect(nextMilestone(start('nature-2h'), day(0)), isNull);
    });

    test('liegt das Ziel einer X-Tage-Challenge vor dem Meilenstein: null',
        () {
      // „21 Tage ohne Zucker“: nach Tag 7 wäre 21 der nächste – das Ziel.
      final sugar = doneRange(start('no-sugar'), 0, 6);
      expect(nextMilestone(sugar, day(6))?.days, 21);
      // Eigene 10-Tage-Challenge: nach 7 Tagen kommt kein Meilenstein mehr.
      var ten = ActiveChallenge(
        id: 'ten',
        template: ChallengeTemplate.custom(
          id: 'custom-ten',
          title: 'Zehn',
          kind: const DailyKind(days: 10),
        ),
        startedOn: day(0),
        reminder: const ReminderTime(7, 0),
      );
      ten = doneRange(ten, 0, 6);
      expect(nextMilestone(ten, day(6)), isNull);
    });
  });
}
