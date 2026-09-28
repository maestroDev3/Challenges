import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String id,
    {Iterable<int> done = const [],
    Iterable<int> missed = const [],
    StreakRule rule = StreakRule.relaxed}) {
  var c = ActiveChallenge(
    id: 'a',
    template: templateById(id)!,
    startedOn: day(0),
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

void main() {
  group('successRate', () {
    test('erledigte Tage / fällige Tage seit Start', () {
      final c = start('wake-5am', done: [0, 1, 2], missed: [3]);
      // heute (Tag 4) ist noch offen und zählt nicht
      expect(c.successRate(day(4)), closeTo(3 / 4, 1e-9));
      // heute abgehakt zählt mit
      expect(c.checkIn(day(4), CheckInStatus.done).successRate(day(4)),
          closeTo(4 / 5, 1e-9));
    });

    test('pausierte Tage zählen nicht als fällig', () {
      final c = start('wake-5am', done: [0, 1])
          .pause(from: day(2), until: day(3));
      expect(c.successRate(day(4)), 1.0);
    });

    test('ohne fällige Tage: null', () {
      expect(start('wake-5am').successRate(day(0)), isNull);
    });

    test('Wochenziel: erreichte Wochen / vergangene Wochen', () {
      var c = start('nature-2h');
      c = c.checkIn(day(1), CheckInStatus.done, minutes: 120);
      c = c.checkIn(day(8), CheckInStatus.done, minutes: 30);
      expect(c.successRate(day(15)), closeTo(1 / 2, 1e-9));
    });

    test('einmalig: null', () {
      expect(start('fasting-24h', done: [0]).successRate(day(3)), isNull);
    });
  });

  group('statusOn', () {
    test('Tagesstatus inklusive Joker', () {
      final c = start('wake-5am',
          done: [0, 1, 2, 3, 4, 5, 6, 8], missed: [7], rule: StreakRule.joker);
      expect(c.statusOn(day(0), today: day(9)), DayStatus.done);
      expect(c.statusOn(day(7), today: day(9)), DayStatus.joker);
      expect(c.statusOn(day(9), today: day(9)), DayStatus.open);
      expect(c.week(day(9))[5], DayStatus.joker);
    });

    test('pausiert und verpasst', () {
      final c = start('wake-5am', missed: [1]).pause(from: day(2), until: day(2));
      expect(c.statusOn(day(1), today: day(3)), DayStatus.missed);
      expect(c.statusOn(day(2), today: day(3)), DayStatus.paused);
    });
  });

  test('journalEntries: neueste zuerst, nur mit Text', () {
    var c = start('excuse-journal');
    c = c.checkIn(day(0), CheckInStatus.done, note: 'Müde');
    c = c.checkIn(day(1), CheckInStatus.done);
    c = c.checkIn(day(2), CheckInStatus.done, note: 'Keine Zeit');
    expect(c.journalEntries.map((e) => e.note), ['Keine Zeit', 'Müde']);
  });
}
