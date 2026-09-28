import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

// Montag, 5. Oktober 2026
final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String templateId) => ActiveChallenge(
      id: 'a1',
      template: templateById(templateId)!,
      startedOn: day(0),
      reminder: const ReminderTime(5, 0),
    );

ActiveChallenge doneOn(ActiveChallenge c, Iterable<int> offsets) {
  for (final o in offsets) {
    c = c.checkIn(day(o), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('checkIn', () {
    test('überschreibt Eintrag desselben Tages', () {
      var c = start('wake-5am');
      c = c.checkIn(day(0), CheckInStatus.missed);
      c = c.checkIn(day(0).add(const Duration(hours: 20)), CheckInStatus.done);
      expect(c.checkIns, hasLength(1));
      expect(c.checkInOn(day(0))!.status, CheckInStatus.done);
    });

    test('ist unveränderlich (liefert neue Instanz)', () {
      final c = start('wake-5am');
      c.checkIn(day(0), CheckInStatus.done);
      expect(c.checkIns, isEmpty);
    });

    test('Journal speichert Notiz', () {
      final c = start('excuse-journal')
          .checkIn(day(0), CheckInStatus.done, note: 'Zu müde');
      expect(c.checkInOn(day(0))!.note, 'Zu müde');
    });

    test('Wochenziel summiert Minuten am selben Tag', () {
      var c = start('nature-2h');
      c = c.checkIn(day(0), CheckInStatus.done, minutes: 30);
      c = c.checkIn(day(0), CheckInStatus.done, minutes: 45);
      expect(c.checkInOn(day(0))!.minutes, 75);
      expect(c.minutesInWeek(day(3)), 75);
    });
  });

  group('currentStreak', () {
    test('zählt aufeinanderfolgende erledigte Tage bis heute', () {
      final c = doneOn(start('wake-5am'), [0, 1, 2]);
      expect(c.currentStreak(day(2)), 3);
    });

    test('heute noch offen: zählt ab gestern', () {
      final c = doneOn(start('wake-5am'), [0, 1, 2]);
      expect(c.currentStreak(day(3)), 3);
    });

    test('Lücke von einem ganzen Tag beendet die Streak', () {
      final c = doneOn(start('wake-5am'), [0, 1, 2]);
      expect(c.currentStreak(day(4)), 0);
    });

    test('missed setzt auf 0', () {
      final c = doneOn(start('wake-5am'), [0, 1])
          .checkIn(day(2), CheckInStatus.missed);
      expect(c.currentStreak(day(2)), 0);
      expect(c.checkIn(day(3), CheckInStatus.done).currentStreak(day(3)), 1);
    });

    test('Wochenziel zählt Wochen mit erreichtem Ziel', () {
      var c = start('nature-2h');
      c = c.checkIn(day(1), CheckInStatus.done, minutes: 120);
      c = c.checkIn(day(8), CheckInStatus.done, minutes: 60);
      c = c.checkIn(day(10), CheckInStatus.done, minutes: 60);
      expect(c.currentStreak(day(10)), 2);
      // neue Woche, Ziel noch nicht erreicht -> Vorwochen zählen
      expect(c.currentStreak(day(15)), 2);
      // eine ganze Woche ohne Ziel -> 0
      expect(c.currentStreak(day(22)), 0);
    });
  });

  test('bestStreak über die gesamte Laufzeit', () {
    var c = doneOn(start('wake-5am'), [0, 1, 2, 3]);
    c = c.checkIn(day(4), CheckInStatus.missed);
    c = doneOn(c, [5, 6]);
    expect(c.bestStreak, 4);
    expect(c.currentStreak(day(6)), 2);
  });

  group('progress', () {
    test('täglich mit N Tagen: erledigte Tage / N', () {
      final c = doneOn(start('no-sugar'), [0, 1, 2]);
      expect(c.progress(day(2)), closeTo(3 / 21, 1e-9));
      expect(c.doneDays, 3);
    });

    test('einmalig: 0 oder 1', () {
      final c = start('fasting-24h');
      expect(c.progress(day(0)), 0);
      expect(c.checkIn(day(0), CheckInStatus.done).progress(day(0)), 1);
    });

    test('Wochenziel: Minuten dieser Woche / Ziel, max 1', () {
      var c = start('nature-2h');
      c = c.checkIn(day(0), CheckInStatus.done, minutes: 60);
      expect(c.progress(day(2)), closeTo(0.5, 1e-9));
      c = c.checkIn(day(1), CheckInStatus.done, minutes: 200);
      expect(c.progress(day(2)), 1);
      expect(c.progress(day(7)), 0); // neue Woche
    });

    test('offen und Journal: null', () {
      expect(start('meditate-sleep').progress(day(0)), isNull);
      expect(start('excuse-journal').progress(day(0)), isNull);
    });
  });

  group('isCompleted', () {
    test('täglich-N nach N erledigten Tagen', () {
      final template = templateById('no-sugar')!;
      final days = (template.kind as DailyKind).days!;
      final c = doneOn(start('no-sugar'), List.generate(days, (i) => i));
      expect(doneOn(start('no-sugar'), [0]).isCompleted, isFalse);
      expect(c.isCompleted, isTrue);
    });

    test('einmalig nach done', () {
      expect(start('silence-24h').isCompleted, isFalse);
      expect(
        start('silence-24h').checkIn(day(0), CheckInStatus.done).isCompleted,
        isTrue,
      );
    });

    test('offene Challenges sind nie abgeschlossen', () {
      expect(doneOn(start('meditate-sleep'), [0, 1, 2]).isCompleted, isFalse);
    });
  });

  test('week liefert die letzten 7 Tage (ältester zuerst)', () {
    var c = doneOn(start('wake-5am'), [0, 2]);
    c = c.checkIn(day(1), CheckInStatus.missed);
    expect(c.week(day(2)), [
      DayStatus.open,
      DayStatus.open,
      DayStatus.open,
      DayStatus.open,
      DayStatus.done,
      DayStatus.missed,
      DayStatus.done,
    ]);
  });
}
