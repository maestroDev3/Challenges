import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String id, {List<int> done = const []}) {
  var c = ActiveChallenge(
    id: 'a',
    template: templateById(id)!,
    startedOn: day(0),
    reminder: const ReminderTime(7, 0),
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('Nachtragen (correct)', () {
    test('setzt, ändert und entfernt Einträge der letzten 7 Tage', () {
      var c = start('wake-5am', done: [3, 4]);
      final today = day(6);
      c = c.correct(day(5), CheckInStatus.done, today: today);
      expect(c.checkInOn(day(5))!.status, CheckInStatus.done);
      expect(c.currentStreak(today), 3);
      c = c.correct(day(4), CheckInStatus.missed, today: today);
      expect(c.checkInOn(day(4))!.status, CheckInStatus.missed);
      c = c.correct(day(4), null, today: today);
      expect(c.checkInOn(day(4)), isNull);
    });

    test('Zukunft, vor dem Start oder älter als 7 Tage ist ein Fehler', () {
      final c = start('wake-5am');
      expect(() => c.correct(day(3), CheckInStatus.done, today: day(2)),
          throwsArgumentError);
      expect(() => c.correct(day(-1), CheckInStatus.done, today: day(2)),
          throwsArgumentError);
      expect(() => c.correct(day(1), CheckInStatus.done, today: day(9)),
          throwsArgumentError);
      expect(c.correct(day(3), CheckInStatus.done, today: day(9)).doneDays, 1);
    });

    test('Wochenziel in Minuten: Korrektur setzt den Wert, statt zu addieren',
        () {
      var c = start('nature-2h')
          .checkIn(day(1), CheckInStatus.done, minutes: 30);
      c = c.correct(day(1), CheckInStatus.done, today: day(2), minutes: 50);
      expect(c.checkInOn(day(1))!.minutes, 50);
    });
  });

  group('Pausieren', () {
    test('pause und isPaused', () {
      final c = start('wake-5am').pause(from: day(2), until: day(4));
      expect(c.isPaused(day(1)), isFalse);
      expect(c.isPaused(day(2)), isTrue);
      expect(c.isPaused(day(4)), isTrue);
      expect(c.isPaused(day(5)), isFalse);
      expect(c.pausedUntil(day(3)), dayOf(day(4)));
    });

    test('Ende vor Beginn ist ein Fehler', () {
      expect(() => start('wake-5am').pause(from: day(4), until: day(2)),
          throwsArgumentError);
    });

    test('pausierte Tage brechen die Streak nicht und zählen nicht', () {
      final paused = start('wake-5am', done: [0, 1, 5])
          .pause(from: day(2), until: day(4));
      expect(paused.currentStreak(day(5)), 3);
      expect(paused.doneDays, 3);
      expect(paused.progress(day(5)), closeTo(3 / 30, 1e-9));

      final notPaused = start('wake-5am', done: [0, 1, 5]);
      expect(notPaused.currentStreak(day(5)), 1);
    });

    test('heute pausiert: Streak bleibt bei gestern', () {
      final c = start('wake-5am', done: [0, 1])
          .pause(from: day(2), until: day(10));
      expect(c.currentStreak(day(2)), 2);
      expect(c.currentStreak(day(6)), 2);
    });

    test('resume beendet die Pause vorzeitig', () {
      var c = start('wake-5am', done: [0, 1])
          .pause(from: day(2), until: day(10));
      c = c.resume(day(4));
      expect(c.isPaused(day(3)), isTrue);
      expect(c.isPaused(day(4)), isFalse);
      // Pause, die heute beginnt, verschwindet ganz
      final d = start('wake-5am').pause(from: day(4), until: day(8)).resume(day(4));
      expect(d.pauses, isEmpty);
    });

    test('week zeigt pausierte Tage', () {
      final c = start('wake-5am', done: [0])
          .pause(from: day(1), until: day(2));
      expect(c.week(day(3)).sublist(3), [
        DayStatus.done,
        DayStatus.paused,
        DayStatus.paused,
        DayStatus.open,
      ]);
    });

    test('Wochenziel: Woche mit Pause bricht die Streak nicht', () {
      var c = start('nature-2h')
          .checkIn(day(1), CheckInStatus.done, minutes: 120);
      c = c.pause(from: day(7), until: day(13));
      c = c.checkIn(day(15), CheckInStatus.done, minutes: 120);
      expect(c.currentStreak(day(16)), 2);
    });
  });
}
