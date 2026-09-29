import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

final t0 = DateTime(2026, 10, 7, 18, 0);
DateTime at(int minutes, [int seconds = 0]) =>
    t0.add(Duration(minutes: minutes, seconds: seconds));

ActiveChallenge running(ChallengeTemplate t) => ActiveChallenge(
      id: 'x',
      template: t,
      startedOn: dayOf(t0),
      reminder: const ReminderTime(18, 0),
    );

final sport = ChallengeTemplate.custom(
    title: 'Sport', kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times));

void main() {
  group('Zieldauer', () {
    test('Katalog: 10 min in die Augen schauen und Meditieren', () {
      expect(templateById('eye-gaze')!.targetDuration,
          const Duration(minutes: 10));
      expect(templateById('meditate-sleep')!.targetDuration,
          const Duration(minutes: 10));
    });

    test('isTimed: Zieldauer oder Wochenziel', () {
      expect(templateById('eye-gaze')!.isTimed, isTrue);
      expect(templateById('nature-2h')!.isTimed, isTrue);
      expect(sport.isTimed, isTrue);
      expect(templateById('cold-shower')!.isTimed, isFalse);
    });
  });

  group('Session', () {
    test('Start merkt die Zeit; zweiter Start ändert nichts', () {
      final c = running(sport).startSession(at(0));
      expect(c.sessionStartedAt, at(0));
      expect(c.startSession(at(5)).sessionStartedAt, at(0));
      expect(c.sessionElapsed(at(12, 34)), const Duration(minutes: 12, seconds: 34));
    });

    test('Wochenziel in Minuten: Sessions addieren sich', () {
      var c = running(templateById('nature-2h')!);
      c = c.startSession(at(0)).stopSession(at(20));
      c = c.startSession(at(30)).stopSession(at(50));
      expect(c.minutesInWeek(t0), 40);
      expect(c.sessionStartedAt, isNull);
    });

    test('Zieldauer erreicht → erledigt', () {
      final c = running(templateById('eye-gaze')!)
          .startSession(at(0))
          .stopSession(at(10));
      expect(c.checkInOn(t0)!.status, CheckInStatus.done);
      expect(c.activityMinutesOn(t0), 10);
    });

    test('Zieldauer nicht erreicht → nicht erledigt, Minuten bleiben', () {
      var c = running(templateById('eye-gaze')!)
          .startSession(at(0))
          .stopSession(at(6));
      expect(c.checkInOn(t0), isNull);
      expect(c.activityMinutesOn(t0), 6);
      c = c.startSession(at(20)).stopSession(at(24));
      expect(c.checkInOn(t0)!.status, CheckInStatus.done);
      expect(c.activityMinutesOn(t0), 10);
    });

    test('ohne Zieldauer (X-mal pro Woche): Stopp zählt als erledigt', () {
      final c = running(sport).startSession(at(0)).stopSession(at(45));
      expect(c.checkInOn(t0)!.status, CheckInStatus.done);
      expect(c.activityMinutesOn(t0), 45);
    });

    test('Ende der Zieldauer', () {
      final c = running(templateById('eye-gaze')!).startSession(at(0));
      expect(c.sessionTargetEnd, at(10));
      expect(running(sport).startSession(at(0)).sessionTargetEnd, isNull);
    });
  });

  test('Benachrichtigungs-Aktion „Stopp“ beendet die Session', () async {
    final repo = FakeChallengeRepository(
        initial: [running(sport).startSession(at(0))]);
    final ok = await handleNotificationAction(repo,
        actionId: actionStop, payload: 'x', now: at(30));
    expect(ok, isTrue);
    expect(repo.items.single.sessionStartedAt, isNull);
    expect(repo.items.single.activityMinutesOn(t0), 30);
  });
}
