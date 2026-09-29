import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
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
}
