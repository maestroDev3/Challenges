import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String id, StreakRule rule,
    {Iterable<int> done = const [], Iterable<int> missed = const []}) {
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

Iterable<int> range(int from, int to) => [for (var i = from; i <= to; i++) i];

void main() {
  test('Standard ist die lockere Regel', () {
    final c = ActiveChallenge(
      id: 'a',
      template: templateById('wake-5am')!,
      startedOn: day(0),
      reminder: const ReminderTime(5, 0),
    );
    expect(c.rule, StreakRule.relaxed);
    expect(c.attempt(day(0)), 1);
  });

  group('Hart', () {
    test('Fehltag setzt Fortschritt auf 0 und startet Versuch 2', () {
      final c = start('no-sugar', StreakRule.strict,
          done: range(0, 4), missed: [5]);
      expect(c.progress(day(5)), 0);
      expect(c.attempt(day(5)), 2);
      expect(c.checkIns, hasLength(6));
      final next = c.checkIn(day(6), CheckInStatus.done);
      expect(next.progress(day(6)), closeTo(1 / 21, 1e-9));
    });

    test('leer gebliebener Tag zählt als Fehltag', () {
      final c = start('no-sugar', StreakRule.strict, done: [0, 1]);
      expect(c.attempt(day(2)), 1); // heute noch offen
      expect(c.attempt(day(3)), 2); // Tag 2 verpasst
    });

    test('geschafft erst nach N Tagen am Stück im aktuellen Versuch', () {
      final strict = start('no-sugar', StreakRule.strict,
          done: [...range(0, 14), ...range(16, 21)], missed: [15]);
      expect(strict.doneDays, 21);
      expect(strict.isCompleted, isFalse);
      final relaxed = start('no-sugar', StreakRule.relaxed,
          done: [...range(0, 14), ...range(16, 21)], missed: [15]);
      expect(relaxed.isCompleted, isTrue);
      final done = start('no-sugar', StreakRule.strict,
          done: [...range(0, 14), ...range(16, 36)], missed: [15]);
      expect(done.isCompleted, isTrue);
    });
  });

  group('Joker', () {
    test('7 Tage am Stück ergeben einen Joker, höchstens zwei', () {
      expect(start('wake-5am', StreakRule.joker, done: range(0, 5))
          .jokers(day(5)), 0);
      expect(start('wake-5am', StreakRule.joker, done: range(0, 6))
          .jokers(day(6)), 1);
      expect(start('wake-5am', StreakRule.joker, done: range(0, 13))
          .jokers(day(13)), 2);
      expect(start('wake-5am', StreakRule.joker, done: range(0, 20))
          .jokers(day(20)), 2);
    });

    test('Fehltag mit Joker hält die Streak und verbraucht den Joker', () {
      final c = start('wake-5am', StreakRule.joker,
          done: [...range(0, 6), 8], missed: [7]);
      expect(c.currentStreak(day(8)), 8);
      expect(c.jokers(day(8)), 0);
      expect(c.doneDays, 8);
      expect(c.jokerDays(day(8)), [dayOf(day(7))]);
    });

    test('leerer Tag verbraucht ebenfalls einen Joker', () {
      final c = start('wake-5am', StreakRule.joker, done: [...range(0, 6), 8]);
      expect(c.currentStreak(day(8)), 8);
    });

    test('ohne Joker fällt die Streak auf 0', () {
      final c = start('wake-5am', StreakRule.joker,
          done: range(0, 5), missed: [6]);
      expect(c.currentStreak(day(6)), 0);
    });
  });

  test('Locker: bisheriges Verhalten', () {
    final c = start('no-sugar', StreakRule.relaxed,
        done: range(0, 4), missed: [5]);
    expect(c.currentStreak(day(5)), 0);
    expect(c.progress(day(5)), closeTo(5 / 21, 1e-9));
    expect(c.attempt(day(5)), 1);
  });

  test('Wochenziel: verfehlte Woche verbraucht einen Joker', () {
    var c = ActiveChallenge(
      id: 'a',
      template: templateById('nature-2h')!,
      startedOn: day(0),
      reminder: const ReminderTime(18, 0),
      rule: StreakRule.joker,
    );
    for (final w in [0, 1, 2, 3, 4, 5, 6, 8]) {
      c = c.checkIn(day(w * 7), CheckInStatus.done, minutes: 120);
    }
    expect(c.currentStreak(day(8 * 7)), 8);
    expect(c.jokers(day(8 * 7)), 0);
  });
}
