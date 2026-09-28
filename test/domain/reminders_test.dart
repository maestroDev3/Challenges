import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';

final now = DateTime(2026, 10, 7, 9, 15);

ActiveChallenge running(String id, {int doneDays = 0}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: dayOf(now),
    reminder: const ReminderTime(7, 0),
  );
  for (var i = 0; i < doneDays; i++) {
    c = c.checkIn(now.subtract(Duration(days: i)), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('handleNotificationAction', () {
    test('done speichert Erledigt für heute', () async {
      final repo = FakeChallengeRepository(initial: [running('wake-5am')]);
      final ok = await handleNotificationAction(repo,
          actionId: actionDone, payload: 'wake-5am', now: now);
      expect(ok, isTrue);
      expect(repo.items.single.checkInOn(now)!.status, CheckInStatus.done);
    });

    test('missed speichert Nicht erledigt für heute', () async {
      final repo = FakeChallengeRepository(initial: [running('wake-5am')]);
      await handleNotificationAction(repo,
          actionId: actionMissed, payload: 'wake-5am', now: now);
      expect(repo.items.single.checkInOn(now)!.status, CheckInStatus.missed);
    });

    test('unbekannte Aktion oder ungültiger Payload ändert nichts', () async {
      final repo = FakeChallengeRepository(initial: [running('wake-5am')]);
      expect(
          await handleNotificationAction(repo,
              actionId: 'snooze', payload: 'wake-5am', now: now),
          isFalse);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: 'gibt-es-nicht', now: now),
          isFalse);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: null, now: now),
          isFalse);
      expect(repo.items.single.checkIns, isEmpty);
    });

    test('Journal übernimmt Texteingabe, ohne Text passiert nichts', () async {
      final repo =
          FakeChallengeRepository(initial: [running('excuse-journal')]);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: 'excuse-journal', now: now),
          isFalse);
      await handleNotificationAction(repo,
          actionId: actionDone,
          payload: 'excuse-journal',
          now: now,
          input: ' Zu spät ins Bett ');
      expect(repo.items.single.checkInOn(now)!.note, 'Zu spät ins Bett');
    });

    test('Wochenziel wird nicht per Aktion abgehakt', () async {
      final repo = FakeChallengeRepository(initial: [running('nature-2h')]);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: 'nature-2h', now: now),
          isFalse);
      expect(repo.items.single.checkIns, isEmpty);
    });
  });

  group('notificationIdFor', () {
    test('ist stabil, positiv und unterscheidet ids', () {
      final a = notificationIdFor('wake-5am-123');
      expect(notificationIdFor('wake-5am-123'), a);
      expect(a, greaterThanOrEqualTo(0));
      expect(a, lessThan(1 << 31));
      expect(notificationIdFor('cold-shower-123'), isNot(a));
    });
  });

  group('nextReminder', () {
    test('heute, wenn die Uhrzeit noch kommt', () {
      expect(nextReminder(now, const ReminderTime(21, 0)),
          DateTime(2026, 10, 7, 21, 0));
    });

    test('morgen, wenn die Uhrzeit vorbei ist', () {
      expect(nextReminder(now, const ReminderTime(7, 0)),
          DateTime(2026, 10, 8, 7, 0));
    });
  });

  test('syncReminders plant laufende und storniert abgeschlossene', () async {
    final done = running('fasting-24h', doneDays: 1);
    final repo = FakeChallengeRepository(
        initial: [running('wake-5am'), running('meditate-sleep'), done]);
    final scheduler = FakeReminderScheduler();
    await syncReminders(repo, scheduler, now: now);
    expect(scheduler.scheduled, {'wake-5am', 'meditate-sleep'});
    expect(scheduler.cancelled, contains('fasting-24h'));
  });

  group('firstReminder', () {
    test('täglich: nächster Termin, pausierte Tage werden übersprungen', () {
      final c = running('wake-5am'); // 07:00, now 09:15
      expect(firstReminder(c, now), DateTime(2026, 10, 8, 7));
      final paused = c.pause(from: DateTime(2026, 10, 8), until: DateTime(2026, 10, 10));
      expect(firstReminder(paused, now), DateTime(2026, 10, 11, 7));
      expect(reminderRepeats(c), isTrue);
    });

    test('einmalig mit Datum: genau am Zieldatum, Vergangenheit → keine', () {
      ActiveChallenge oneTime(DateTime date) => ActiveChallenge(
            id: 'x',
            template: ChallengeTemplate.custom(
                title: 'Schweigen',
                kind: OneTimeKind(const Duration(hours: 24), date: date)),
            startedOn: dayOf(now),
            reminder: const ReminderTime(8, 30),
          );
      final future = oneTime(DateTime(2026, 10, 10));
      expect(firstReminder(future, now), DateTime(2026, 10, 10, 8, 30));
      expect(reminderRepeats(future), isFalse);
      expect(firstReminder(oneTime(DateTime(2026, 10, 7)), now), isNull);
      expect(firstReminder(oneTime(DateTime(2026, 10, 6)), now), isNull);
    });

    test('archiviert oder einmalig erledigt → keine Erinnerung', () {
      expect(firstReminder(running('wake-5am').finish(now), now), isNull);
      expect(firstReminder(running('fasting-24h', doneDays: 1), now), isNull);
    });
  });

  group('reminderActionsFor', () {
    test('passende Aktionen je Art', () {
      expect(reminderActionsFor(const DailyKind()), ReminderActions.doneMissed);
      expect(reminderActionsFor(const JournalKind()), ReminderActions.journalInput);
      expect(reminderActionsFor(const WeeklyGoalKind(3, unit: WeeklyUnit.times)),
          ReminderActions.doneMissed);
      expect(reminderActionsFor(const WeeklyGoalKind(120)), ReminderActions.none);
    });
  });

  group('handleNotificationAction (neue Arten)', () {
    test('Wochenziel X-mal: Erledigt zählt für die Woche', () async {
      final sport = ChallengeTemplate.custom(
          title: 'Sport', kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times));
      final c = ActiveChallenge(
        id: 'sport',
        template: sport,
        startedOn: dayOf(now),
        reminder: const ReminderTime(18, 0),
      );
      final repo = FakeChallengeRepository(initial: [c]);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: 'sport', now: now),
          isTrue);
      expect(repo.items.single.doneDaysInWeek(now), 1);
    });

    test('archivierte Challenges ändern sich nicht', () async {
      final repo = FakeChallengeRepository(
          archived: [running('wake-5am').finish(now)]);
      expect(
          await handleNotificationAction(repo,
              actionId: actionDone, payload: 'wake-5am', now: now),
          isFalse);
    });

    test('erreichtes Ziel wird automatisch archiviert', () async {
      final repo = FakeChallengeRepository(
          initial: [running('fasting-24h')], today: now);
      await handleNotificationAction(repo,
          actionId: actionDone, payload: 'fasting-24h', now: now);
      expect(repo.items, isEmpty);
      expect(repo.archivedItems.single.status, ChallengeStatus.completed);
    });
  });

  test('syncReminders plant pausierte Challenges (nach der Pause)', () async {
    final paused = running('wake-5am')
        .pause(from: DateTime(2026, 10, 7), until: DateTime(2026, 10, 9));
    final repo = FakeChallengeRepository(initial: [paused]);
    final scheduler = FakeReminderScheduler();
    await syncReminders(repo, scheduler, now: now);
    expect(scheduler.scheduled, {'wake-5am'});
  });
}
