import 'dart:convert';

import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:flutter_test/flutter_test.dart';

final exportedAt = DateTime.utc(2026, 9, 29, 18, 30);

ChallengeStore richStore() {
  final morning = ChallengeTemplate.custom(
    title: 'Morgen',
    emoji: '🌅',
    description: 'Routine',
    kind: const DailyKind(days: 30),
    steps: const ['Wasser', 'Dehnen'],
  );
  final sport = ChallengeTemplate.custom(
    title: 'Sport',
    kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times, weekdays: {1, 3, 5}),
    targetDuration: const Duration(minutes: 45),
  );
  final start = DateTime.utc(2026, 9, 1);
  final routine = ActiveChallenge(
    id: 'morgen-1',
    template: morning,
    startedOn: start,
    reminder: const ReminderTime(6, 15),
    rule: StreakRule.joker,
  )
      .checkIn(DateTime(2026, 9, 1), CheckInStatus.done)
      .checkIn(DateTime(2026, 9, 2), CheckInStatus.missed)
      .toggleStep(DateTime(2026, 9, 3), 1)
      .pause(from: DateTime(2026, 9, 10), until: DateTime(2026, 9, 12));
  final training = ActiveChallenge(
    id: 'sport-1',
    template: sport,
    startedOn: start,
    reminder: const ReminderTime(18, 0),
  )
      .startSession(DateTime(2026, 9, 4, 18))
      .stopSession(DateTime(2026, 9, 4, 18, 40))
      .checkIn(DateTime(2026, 9, 5), CheckInStatus.done, minutes: 30);
  final diet = ActiveChallenge(
    id: 'fasting-24h-1',
    template: templateById('fasting-24h')!,
    startedOn: start,
    reminder: const ReminderTime(9, 0),
  ).startWindow(DateTime(2026, 9, 6, 8));
  final journal = ActiveChallenge(
    id: 'excuse-journal-1',
    template: templateById('excuse-journal')!,
    startedOn: start,
    reminder: const ReminderTime(21, 0),
  )
      .checkIn(DateTime(2026, 9, 2), CheckInStatus.done, note: 'Müde; "später"')
      .finish(DateTime(2026, 9, 20));
  return ChallengeStore(
    active: [routine, training, diet],
    archived: [journal],
    customTemplates: [morning, sport],
  );
}

void main() {
  group('Backup-Datei', () {
    test('Round-Trip erhält den kompletten Stand', () {
      final store = richStore();
      final text = encodeBackup(store, exportedAt: exportedAt);
      final backup = decodeBackup(text);

      expect(backup.exportedAt, exportedAt);
      expect(encodeBackup(backup.store, exportedAt: exportedAt), text);

      final s = backup.store;
      expect(s.active.map((c) => c.id), ['morgen-1', 'sport-1', 'fasting-24h-1']);
      expect(s.archived.single.id, 'excuse-journal-1');
      expect(s.customTemplates.map((t) => t.title), ['Morgen', 'Sport']);
      final routine = s.active[0];
      expect(routine.rule, StreakRule.joker);
      expect(routine.reminder, const ReminderTime(6, 15));
      expect(routine.template.steps, ['Wasser', 'Dehnen']);
      expect(routine.stepsDoneOn(DateTime(2026, 9, 3)), {1});
      expect(routine.isPaused(DateTime(2026, 9, 11)), isTrue);
      expect(routine.doneDays, 1);
      final training = s.active[1];
      expect((training.template.kind as WeeklyGoalKind).weekdays, {1, 3, 5});
      expect(training.template.targetDuration, const Duration(minutes: 45));
      expect(training.activityMinutesOn(DateTime(2026, 9, 4)), 40);
      expect(training.checkInOn(DateTime(2026, 9, 5))?.minutes, 30);
      expect(s.active[2].windowStartedAt, isNotNull);
      final journal = s.archived.single;
      expect(journal.status, ChallengeStatus.ended);
      expect(journal.checkInOn(DateTime(2026, 9, 2))?.note, 'Müde; "später"');
    });

    test('Datei ist erkennbar: Format, Version und Exportdatum', () {
      final json = jsonDecode(encodeBackup(const ChallengeStore(),
          exportedAt: exportedAt)) as Map<String, dynamic>;
      expect(json['format'], 'ritual-backup');
      expect(json['version'], backupVersion);
      expect(json['exportedAt'], exportedAt.toIso8601String());
      expect(json['challenges'], isEmpty);
      expect(json['templates'], isEmpty);
    });

    test('ungültige Dateien werfen FormatException', () {
      final valid = jsonDecode(encodeBackup(richStore(), exportedAt: exportedAt))
          as Map<String, dynamic>;
      final broken = <String>[
        '',
        'kein json',
        '[1, 2]',
        jsonEncode({...valid, 'format': 'loop-habits'}),
        jsonEncode({...valid, 'version': backupVersion + 1}),
        jsonEncode({...valid}..remove('challenges')),
        jsonEncode({...valid}..remove('exportedAt')),
        jsonEncode({
          ...valid,
          'challenges': [
            {'id': 'x'}
          ]
        }),
      ];
      for (final text in broken) {
        expect(() => decodeBackup(text), throwsFormatException, reason: text);
      }
    });
  });

  group('Speicherformat', () {
    test('encodeStore/decodeStore sind verlustfrei', () {
      final text = encodeStore(richStore());
      expect(encodeStore(decodeStore(text)), text);
      expect((jsonDecode(text) as Map)['version'], 2);
    });
  });
}
