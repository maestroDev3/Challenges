import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

// Montag, 5. Oktober 2026
final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

void main() {
  group('ChallengeTemplate.custom', () {
    test('erzeugt eindeutige ids mit Präfix custom- und trimmt den Titel', () {
      final a = ChallengeTemplate.custom(
          title: '  Laufen  ', kind: const DailyKind(days: 30));
      final b = ChallengeTemplate.custom(
          title: 'Laufen', kind: const DailyKind(days: 30));
      expect(a.id, startsWith('custom-'));
      expect(a.id, isNot(b.id));
      expect(a.title, 'Laufen');
      expect(a.isCustom, isTrue);
    });

    test('übernimmt Emoji und Beschreibung, hat sinnvolle Standards', () {
      final t = ChallengeTemplate.custom(
          title: 'Sport', kind: const DailyKind(), emoji: '🏃', description: 'x');
      expect(t.emoji, '🏃');
      expect(t.description, 'x');
      final d = ChallengeTemplate.custom(title: 'Sport', kind: const DailyKind());
      expect(d.emoji, isNotEmpty);
      expect(d.description, '');
    });

    test('leerer Titel ist ein Fehler', () {
      expect(() => ChallengeTemplate.custom(title: '   ', kind: const DailyKind()),
          throwsArgumentError);
    });

    test('X Tage nur 1–365', () {
      expect(() => ChallengeTemplate.custom(title: 'a', kind: const DailyKind(days: 0)),
          throwsArgumentError);
      expect(() => ChallengeTemplate.custom(title: 'a', kind: const DailyKind(days: 366)),
          throwsArgumentError);
      expect(ChallengeTemplate.custom(title: 'a', kind: const DailyKind(days: 365)).title, 'a');
    });

    test('Wochenziel: Mal 1–7, Minuten 1–10080', () {
      ChallengeTemplate make(ChallengeKind k) =>
          ChallengeTemplate.custom(title: 'a', kind: k);
      expect(() => make(const WeeklyGoalKind(0, unit: WeeklyUnit.times)),
          throwsArgumentError);
      expect(() => make(const WeeklyGoalKind(8, unit: WeeklyUnit.times)),
          throwsArgumentError);
      expect(() => make(const WeeklyGoalKind(10081)), throwsArgumentError);
      expect(make(const WeeklyGoalKind(7, unit: WeeklyUnit.times)).title, 'a');
      expect(make(const WeeklyGoalKind(10080)).title, 'a');
    });

    test('Katalog-Vorlagen sind nicht custom', () {
      expect(templateById('wake-5am')!.isCustom, isFalse);
    });
  });

  group('kindLabel', () {
    test('neue Varianten', () {
      ChallengeTemplate make(ChallengeKind k) =>
          ChallengeTemplate.custom(title: 'a', kind: k);
      expect(make(const WeeklyGoalKind(3, unit: WeeklyUnit.times)).kindLabel,
          '3×/Woche');
      expect(
          make(OneTimeKind(const Duration(hours: 24), date: DateTime(2026, 10, 3)))
              .kindLabel,
          'einmalig · 03.10.');
      expect(make(const DailyKind(days: 66)).kindLabel, '66 Tage');
      expect(make(const DailyKind()).kindLabel, 'täglich');
      expect(make(const WeeklyGoalKind(90)).kindLabel, '90 min/Woche');
    });
  });

  group('Wochenziel X-mal pro Woche', () {
    ActiveChallenge start() => ActiveChallenge(
          id: 'a',
          template: ChallengeTemplate.custom(
              title: 'Sport',
              kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times)),
          startedOn: day(0),
          reminder: const ReminderTime(18, 0),
        );

    test('progress = erledigte Tage dieser Woche / Ziel', () {
      var c = start();
      c = c.checkIn(day(0), CheckInStatus.done);
      c = c.checkIn(day(2), CheckInStatus.done);
      expect(c.progress(day(3)), closeTo(2 / 3, 1e-9));
      expect(c.doneDaysInWeek(day(3)), 2);
      c = c.checkIn(day(4), CheckInStatus.done);
      c = c.checkIn(day(5), CheckInStatus.done);
      expect(c.progress(day(5)), 1);
    });

    test('mehrfaches Abhaken am selben Tag zählt einmal', () {
      var c = start();
      c = c.checkIn(day(0), CheckInStatus.done);
      c = c.checkIn(day(0), CheckInStatus.done);
      expect(c.doneDaysInWeek(day(0)), 1);
    });

    test('Streak zählt Wochen mit erreichtem Ziel', () {
      var c = start();
      for (final d in [0, 1, 2, 7, 9, 11]) {
        c = c.checkIn(day(d), CheckInStatus.done);
      }
      expect(c.currentStreak(day(12)), 2);
      expect(c.currentStreak(day(15)), 2); // neue Woche noch offen
      expect(c.currentStreak(day(22)), 0); // Woche 3 verfehlt
    });
  });
}
