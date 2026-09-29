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
  test('neue Challenges sind aktiv', () {
    final c = start('wake-5am');
    expect(c.status, ChallengeStatus.active);
    expect(c.isArchived, isFalse);
    expect(c.finishedOn, isNull);
  });

  test('finish: completed bei erreichtem Ziel', () {
    final c = start('no-sugar', done: List.generate(21, (i) => i))
        .finish(day(20).add(const Duration(hours: 21)));
    expect(c.status, ChallengeStatus.completed);
    expect(c.finishedOn, dayOf(day(20)));
    expect(c.isArchived, isTrue);
  });

  test('finish: ended, wenn Ziel nicht erreicht', () {
    final c = start('meditate-sleep', done: [0, 1]).finish(day(3));
    expect(c.status, ChallengeStatus.ended);
    expect(c.finishedOn, dayOf(day(3)));
  });

  test('Check-ins auf archivierten Challenges werden ignoriert', () {
    final c = start('meditate-sleep', done: [0]).finish(day(1));
    final after = c.checkIn(day(1), CheckInStatus.done);
    expect(identical(after, c), isTrue);
    expect(after.checkIns, hasLength(1));
  });

  test('shouldAutoFinish nur bei erreichtem Ziel', () {
    expect(start('no-sugar', done: List.generate(21, (i) => i))
        .shouldAutoFinish(day(20)), isTrue);
    expect(start('no-sugar', done: [0, 1]).shouldAutoFinish(day(1)), isFalse);
    expect(start('fasting-24h', done: [0]).shouldAutoFinish(day(0)), isTrue);
    expect(start('meditate-sleep', done: List.generate(40, (i) => i))
        .shouldAutoFinish(day(39)), isFalse);
    expect(start('nature-2h').shouldAutoFinish(day(0)), isFalse);
    final archived = start('fasting-24h', done: [0]).finish(day(0));
    expect(archived.shouldAutoFinish(day(0)), isFalse);
  });

  test('Verlauf, beste Streak und erledigte Tage bleiben erhalten', () {
    final c = start('meditate-sleep', done: [0, 1, 2, 4]).finish(day(5));
    expect(c.bestStreak, 3);
    expect(c.doneDays, 4);
  });

  test('reopen holt die Challenge mit Verlauf zurück', () {
    final c = start('meditate-sleep', done: [0, 1]).finish(day(2)).reopen();
    expect(c.status, ChallengeStatus.active);
    expect(c.finishedOn, isNull);
    expect(c.doneDays, 2);
    expect(c.checkIn(day(2), CheckInStatus.done).doneDays, 3);
  });
}
