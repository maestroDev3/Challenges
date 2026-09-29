import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

final monday = DateTime(2026, 10, 5);
DateTime day(int offset) => monday.add(Duration(days: offset));

final routine = ChallengeTemplate.custom(
  title: 'Morgenroutine',
  kind: const DailyKind(days: 30),
  steps: [' Wasser ', 'Bett machen', '', 'Dehnen', 'Tag planen'],
);

ActiveChallenge start() => ActiveChallenge(
      id: 'r',
      template: routine,
      startedOn: day(0),
      reminder: const ReminderTime(6, 0),
    );

void main() {
  test('Schritte werden getrimmt, leere entfallen', () {
    expect(routine.steps, ['Wasser', 'Bett machen', 'Dehnen', 'Tag planen']);
  });

  test('Katalog: Morgenroutine hat Schritte', () {
    expect(templateById('morning-routine')!.steps, isNotEmpty);
  });

  test('Teilfortschritt ist sichtbar, Tag noch nicht erledigt', () {
    var c = start().toggleStep(day(0), 0).toggleStep(day(0), 2);
    expect(c.stepsDoneOn(day(0)), {0, 2});
    expect(c.checkInOn(day(0)), isNull);
  });

  test('alle Schritte → Tag erledigt; einen abwählen → wieder offen', () {
    var c = start();
    for (var i = 0; i < 4; i++) {
      c = c.toggleStep(day(0), i);
    }
    expect(c.checkInOn(day(0))!.status, CheckInStatus.done);
    c = c.toggleStep(day(0), 1);
    expect(c.checkInOn(day(0)), isNull);
    expect(c.stepsDoneOn(day(0)), {0, 2, 3});
  });

  test('Schritte sind pro Tag getrennt', () {
    final c = start().toggleStep(day(0), 0).toggleStep(day(1), 3);
    expect(c.stepsDoneOn(day(0)), {0});
    expect(c.stepsDoneOn(day(1)), {3});
  });

  test('„Erledigt“ (z. B. aus der Benachrichtigung) hakt alle Schritte ab', () {
    final c = start().checkIn(day(0), CheckInStatus.done);
    expect(c.stepsDoneOn(day(0)), {0, 1, 2, 3});
    final missed = c.checkIn(day(0), CheckInStatus.missed);
    expect(missed.stepsDoneOn(day(0)), isEmpty);
  });
}
