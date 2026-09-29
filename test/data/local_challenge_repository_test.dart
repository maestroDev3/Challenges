import 'dart:convert';

import 'package:challenges/data/local_challenge_repository.dart';
import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime(2026, 10, 5, 8, 30);

Future<LocalChallengeRepository> newRepo() async =>
    LocalChallengeRepository(await SharedPreferences.getInstance(),
        clock: () => now);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final sport = ChallengeTemplate.custom(
  title: 'Sport',
  emoji: '🏃',
  description: 'Laufen oder Gym',
  kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('aktive Challenges', () {
    test('start legt aktive Challenge an', () async {
      final repo = await newRepo();
      final c = await repo.start(
          templateById('wake-5am')!, const ReminderTime(5, 0));
      expect(c.template.id, 'wake-5am');
      expect(c.reminder, const ReminderTime(5, 0));
      expect(c.startedOn, dayOf(now));
      expect(c.rule, StreakRule.relaxed);
      expect((await repo.active()).map((a) => a.id), [c.id]);
    });

    test('start mit Regel speichert die Regel', () async {
      final repo = await newRepo();
      await repo.start(templateById('no-sugar')!, const ReminderTime(9, 0),
          rule: StreakRule.strict);
      final reloaded = (await (await newRepo()).active()).single;
      expect(reloaded.rule, StreakRule.strict);
    });

    test('unpassende Regel wird beim Start und beim Laden zu Locker', () async {
      final repo = await newRepo();
      final c = await repo.start(
          templateById('meditate-sleep')!, const ReminderTime(22, 0),
          rule: StreakRule.strict);
      expect(c.rule, StreakRule.relaxed);
      await repo.save(c.copyWith(rule: StreakRule.strict));
      expect((await (await newRepo()).active()).single.rule, StreakRule.relaxed);
    });

    test('start derselben Vorlage liefert die laufende Challenge', () async {
      final repo = await newRepo();
      final a = await repo.start(
          templateById('wake-5am')!, const ReminderTime(5, 0));
      final b = await repo.start(
          templateById('wake-5am')!, const ReminderTime(6, 0));
      expect(b.id, a.id);
      expect(await repo.active(), hasLength(1));
    });

    test('save persistiert Check-ins, Pausen und Regel', () async {
      final repo = await newRepo();
      var c = await repo.start(
          templateById('nature-2h')!, const ReminderTime(18, 15));
      c = c
          .checkIn(now, CheckInStatus.done, minutes: 40, note: 'Wald')
          .pause(from: DateTime(2026, 10, 7), until: DateTime(2026, 10, 9))
          .copyWith(rule: StreakRule.joker);
      await repo.save(c);

      final reloaded = (await (await newRepo()).active()).single;
      expect(reloaded.id, c.id);
      expect(reloaded.template.id, 'nature-2h');
      expect(reloaded.reminder, const ReminderTime(18, 15));
      expect(reloaded.startedOn, dayOf(now));
      final ci = reloaded.checkInOn(now)!;
      expect(ci.status, CheckInStatus.done);
      expect(ci.minutes, 40);
      expect(ci.note, 'Wald');
      expect(reloaded.isPaused(DateTime(2026, 10, 8)), isTrue);
      expect(reloaded.rule, StreakRule.joker);
    });

    test('byId findet aktive und archivierte Challenges', () async {
      final repo = await newRepo();
      final c = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      expect((await repo.byId(c.id))?.id, c.id);
      await repo.finish(c.id);
      expect((await repo.byId(c.id))?.isArchived, isTrue);
      expect(await repo.byId('gibt-es-nicht'), isNull);
    });
  });

  group('Archiv', () {
    test('finish archiviert: active nur aktive, archived nur archivierte',
        () async {
      final repo = await newRepo();
      final a = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      await repo.start(templateById('wake-5am')!, const ReminderTime(5, 0));
      final finished = await repo.finish(a.id);
      expect(finished!.status, ChallengeStatus.ended);
      expect(finished.finishedOn, dayOf(now));
      expect((await repo.active()).map((c) => c.template.id), ['wake-5am']);
      final archived = (await (await newRepo()).archived()).single;
      expect(archived.id, a.id);
      expect(archived.status, ChallengeStatus.ended);
      expect(archived.finishedOn, dayOf(now));
    });

    test('archivierte Vorlage kann neu gestartet werden', () async {
      final repo = await newRepo();
      final a = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      await repo.finish(a.id);
      final b = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      expect(b.id, isNot(a.id));
      expect(await repo.active(), hasLength(1));
      expect(await repo.archived(), hasLength(1));
    });

    test('reopen holt archivierte Challenge mit Verlauf zurück', () async {
      final repo = await newRepo();
      var c = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      await repo.save(c.checkIn(now, CheckInStatus.done));
      await repo.finish(c.id);
      final reopened = await repo.reopen(c.id);
      expect(reopened.status, ChallengeStatus.active);
      final loaded = await newRepo();
      expect((await loaded.active()).single.doneDays, 1);
      expect(await loaded.archived(), isEmpty);
    });

    test('reopen scheitert, wenn dieselbe Vorlage schon läuft', () async {
      final repo = await newRepo();
      final a = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      await repo.finish(a.id);
      await repo.start(templateById('cold-shower')!, const ReminderTime(7, 0));
      await expectLater(repo.reopen(a.id), throwsStateError);
    });

    test('delete entfernt endgültig', () async {
      final repo = await newRepo();
      final a = await repo.start(
          templateById('cold-shower')!, const ReminderTime(7, 0));
      final b = await repo.start(
          templateById('wake-5am')!, const ReminderTime(5, 0));
      await repo.finish(b.id);
      await repo.delete(a.id);
      await repo.delete(b.id);
      expect(await repo.active(), isEmpty);
      expect(await repo.archived(), isEmpty);
    });
  });

  group('eigene Vorlagen', () {
    test('anlegen, ändern, löschen – über Instanzen hinweg', () async {
      final repo = await newRepo();
      await repo.saveTemplate(sport);
      var loaded = (await (await newRepo()).customTemplates()).single;
      expect(loaded.id, sport.id);
      expect(loaded.title, 'Sport');
      expect(loaded.emoji, '🏃');
      expect(loaded.description, 'Laufen oder Gym');
      final kind = loaded.kind as WeeklyGoalKind;
      expect(kind.target, 3);
      expect(kind.unit, WeeklyUnit.times);

      await repo.saveTemplate(sport.copyWith(title: 'Sport 🔥'));
      loaded = (await (await newRepo()).customTemplates()).single;
      expect(loaded.title, 'Sport 🔥');

      await repo.deleteTemplate(sport.id);
      expect(await (await newRepo()).customTemplates(), isEmpty);
    });

    test('alle Arten überstehen den Round-Trip', () async {
      final repo = await newRepo();
      final templates = [
        ChallengeTemplate.custom(title: 'a', kind: const DailyKind()),
        ChallengeTemplate.custom(title: 'b', kind: const DailyKind(days: 66)),
        ChallengeTemplate.custom(title: 'c', kind: const WeeklyGoalKind(90)),
        ChallengeTemplate.custom(
            title: 'd',
            kind: OneTimeKind(const Duration(hours: 24),
                date: DateTime(2026, 10, 10))),
        ChallengeTemplate.custom(title: 'e', kind: const JournalKind()),
      ];
      for (final t in templates) {
        await repo.saveTemplate(t);
      }
      final loaded = await (await newRepo()).customTemplates();
      expect(loaded.map((t) => t.kindLabel),
          templates.map((t) => t.kindLabel));
    });

    test('Schritte und abgehakte Schritte werden gespeichert', () async {
      final repo = await newRepo();
      final routine = ChallengeTemplate.custom(
          title: 'Routine', kind: const DailyKind(), steps: ['A', 'B', 'C']);
      await repo.saveTemplate(routine);
      final c = await repo.start(routine, const ReminderTime(6, 0));
      await repo.save(c.toggleStep(now, 0).toggleStep(now, 2));
      final loaded = (await (await newRepo()).active()).single;
      expect(loaded.template.steps, ['A', 'B', 'C']);
      expect(loaded.stepsDoneOn(now), {0, 2});
    });

    test('laufende Session und Zieldauer überstehen einen Neustart', () async {
      final repo = await newRepo();
      final t = ChallengeTemplate.custom(
          title: 'Lesen',
          kind: const DailyKind(),
          targetDuration: const Duration(minutes: 20));
      await repo.saveTemplate(t);
      final c = await repo.start(t, const ReminderTime(20, 0));
      final started = DateTime(2026, 10, 5, 20, 3);
      await repo.save(c.startSession(started).stopSession(
              started.add(const Duration(minutes: 5))).startSession(started
              .add(const Duration(minutes: 10))));
      final loaded = (await (await newRepo()).active()).single;
      expect(loaded.template.targetDuration, const Duration(minutes: 20));
      expect(loaded.sessionStartedAt, started.add(const Duration(minutes: 10)));
      expect(loaded.activityMinutesOn(started), 5);
    });

    test('Wochentage werden gespeichert', () async {
      final repo = await newRepo();
      final t = ChallengeTemplate.custom(
          title: 'Laufen',
          kind: const WeeklyGoalKind(3,
              unit: WeeklyUnit.times, weekdays: {1, 3, 5}));
      await repo.saveTemplate(t);
      final loaded = (await (await newRepo()).customTemplates()).single;
      expect((loaded.kind as WeeklyGoalKind).weekdays, {1, 3, 5});
    });

    test('Challenge mit eigener Vorlage wird korrekt geladen', () async {
      final repo = await newRepo();
      await repo.saveTemplate(sport);
      await repo.start(sport, const ReminderTime(18, 0));
      final c = (await (await newRepo()).active()).single;
      expect(c.template.title, 'Sport');
      expect(c.template.kindLabel, '3×/Woche');
    });

    test('Ändern der Vorlage wirkt auf die laufende Challenge', () async {
      final repo = await newRepo();
      await repo.saveTemplate(sport);
      await repo.start(sport, const ReminderTime(18, 0));
      await repo.saveTemplate(sport.copyWith(title: 'Training'));
      expect((await (await newRepo()).active()).single.template.title,
          'Training');
    });

    test('Vorlage mit laufender Challenge kann nicht gelöscht werden',
        () async {
      final repo = await newRepo();
      await repo.saveTemplate(sport);
      final c = await repo.start(sport, const ReminderTime(18, 0));
      await expectLater(repo.deleteTemplate(sport.id), throwsStateError);

      await repo.finish(c.id);
      await repo.deleteTemplate(sport.id);
      // Archiv behält eine Kopie der Vorlage
      final archived = (await (await newRepo()).archived()).single;
      expect(archived.template.title, 'Sport');
    });
  });


  group('replaceAll', () {
    test('ersetzt aktive, archivierte Challenges und Vorlagen vollständig',
        () async {
      final repo = await newRepo();
      await repo.saveTemplate(sport);
      await repo.start(templateById('cold-shower')!, const ReminderTime(7, 0));

      final running = ActiveChallenge(
        id: 'wake-5am-x',
        template: templateById('wake-5am')!,
        startedOn: dayOf(now),
        reminder: const ReminderTime(5, 0),
      ).checkIn(now, CheckInStatus.done);
      final other = ChallengeTemplate.custom(
          title: 'Lesen', kind: const JournalKind());
      final done = ActiveChallenge(
        id: 'lesen-x',
        template: other,
        startedOn: dayOf(now),
        reminder: const ReminderTime(20, 0),
      ).finish(now);
      await repo.replaceAll(ChallengeStore(
          active: [running], archived: [done], customTemplates: [other]));

      final loaded = await newRepo();
      expect((await loaded.active()).map((c) => c.id), ['wake-5am-x']);
      expect((await loaded.active()).single.doneDays, 1);
      expect((await loaded.archived()).single.template.title, 'Lesen');
      expect((await loaded.customTemplates()).map((t) => t.title), ['Lesen']);
    });

    test('emittiert den neuen Stand', () async {
      final repo = await newRepo();
      await repo.start(templateById('cold-shower')!, const ReminderTime(7, 0));
      final events = <int>[];
      final sub = repo.watchStore().listen((s) => events.add(s.active.length));
      await settle();
      await repo.replaceAll(const ChallengeStore());
      await settle();
      await sub.cancel();
      expect(events, [1, 0]);
    });
  });

  test('Daten im alten Format v1 werden übernommen', () async {
    SharedPreferences.setMockInitialValues({
      'active_challenges_v1': jsonEncode([
        {
          'id': 'wake-5am-1',
          'template': 'wake-5am',
          'startedOn': '2026-09-28T00:00:00.000Z',
          'reminder': [5, 0],
          'checkIns': [
            {'day': '2026-09-28T00:00:00.000Z', 'status': 'done'},
          ],
        },
      ]),
    });
    final repo = await newRepo();
    final c = (await repo.active()).single;
    expect(c.id, 'wake-5am-1');
    expect(c.status, ChallengeStatus.active);
    expect(c.rule, StreakRule.relaxed);
    expect(c.doneDays, 1);
    // nach dem nächsten Schreiben bleibt alles erhalten
    await repo.save(c.checkIn(now, CheckInStatus.done));
    expect((await (await newRepo()).active()).single.doneDays, 2);
  });

  test('watchStore emittiert aktive, archivierte und Vorlagen', () async {
    final repo = await newRepo();
    final events = <String>[];
    final sub = repo.watchStore().listen((s) => events.add(
        '${s.active.length}/${s.archived.length}/${s.customTemplates.length}'));
    await settle();
    await repo.saveTemplate(sport);
    await settle();
    final c = await repo.start(sport, const ReminderTime(18, 0));
    await settle();
    await repo.finish(c.id);
    await settle();
    await sub.cancel();
    expect(events, ['0/0/0', '0/0/1', '1/0/1', '0/1/1']);
  });

  test('watch emittiert aktuellen Stand und jede Änderung', () async {
    final repo = await newRepo();
    final lengths = <int>[];
    final sub = repo.watch().listen((l) => lengths.add(l.length));
    await settle();
    final c = await repo.start(
        templateById('cold-shower')!, const ReminderTime(7, 0));
    await settle();
    await repo.delete(c.id);
    await settle();
    await sub.cancel();
    expect(lengths, [0, 1, 0]);
  });
}
