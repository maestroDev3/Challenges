import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

ActiveChallenge start(String templateId, {Iterable<int> done = const []}) {
  var c = ActiveChallenge(
    id: templateId,
    template: templateById(templateId)!,
    startedOn: day(0),
    reminder: const ReminderTime(7, 0),
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('profileStats', () {
    test('zählt laufende und geschaffte Challenges, Tage, Streak und Abzeichen',
        () {
      final store = ChallengeStore(
        active: [
          start('wake-5am', done: [0, 1, 2, 3, 4, 5, 6, 7]),
          start('cold-shower', done: [0, 1, 2]),
        ],
        archived: [
          start('fasting-24h', done: [0]).finish(day(0)),
          start('no-sugar').finish(day(1)),
        ],
      );

      final stats = profileStats(store);

      expect(stats.running, 2);
      expect(stats.completed, 1);
      expect(stats.doneDays, 12);
      expect(stats.longestStreak, 8);
      expect(stats.badges, 1);
      expect(stats.isEmpty, isFalse);
    });

    test('ohne Challenges ist alles null und die Übersicht leer', () {
      final stats = profileStats(const ChallengeStore());
      expect(stats.running, 0);
      expect(stats.completed, 0);
      expect(stats.doneDays, 0);
      expect(stats.longestStreak, 0);
      expect(stats.badges, 0);
      expect(stats.isEmpty, isTrue);
    });
  });
}
