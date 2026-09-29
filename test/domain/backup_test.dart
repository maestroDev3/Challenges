import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/backup.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';

final exportedAt = DateTime.utc(2026, 9, 28, 20);

ActiveChallenge running(String id, String templateId) => ActiveChallenge(
      id: id,
      template: templateById(templateId)!,
      startedOn: DateTime.utc(2026, 9, 1),
      reminder: const ReminderTime(7, 0),
    );

String backupFile() {
  final reading =
      ChallengeTemplate.custom(title: 'Lesen', kind: const JournalKind());
  return encodeBackup(
    ChallengeStore(
      active: [running('wake-1', 'wake-5am'), running('cold-1', 'cold-shower')],
      archived: [running('eye-1', 'eye-gaze').finish(DateTime(2026, 9, 10))],
      customTemplates: [reading],
    ),
    exportedAt: exportedAt,
  );
}

void main() {
  group('describeBackup', () {
    test('nennt Anzahlen und Exportdatum', () {
      final summary = describeBackup(backupFile());
      expect(summary.active, 2);
      expect(summary.archived, 1);
      expect(summary.templates, 1);
      expect(summary.exportedAt, exportedAt);
    });

    test('ungültige Datei wirft FormatException', () {
      expect(() => describeBackup('{}'), throwsFormatException);
    });
  });

  group('restoreBackup', () {
    test('storniert alte Erinnerungen, ersetzt den Stand, plant neue', () async {
      final repo = FakeChallengeRepository(
          initial: [running('old-1', 'no-sugar')],
          archived: [running('old-2', 'silence-24h').finish(DateTime(2026, 9, 2))]);
      final scheduler = FakeReminderScheduler();

      await restoreBackup(repo, scheduler, backupFile());

      expect(scheduler.cancelled, ['old-1']);
      expect(scheduler.scheduled, {'wake-1', 'cold-1'});
      expect(repo.items.map((c) => c.id), ['wake-1', 'cold-1']);
      expect(repo.archivedItems.map((c) => c.id), ['eye-1']);
      expect(repo.templates.map((t) => t.title), ['Lesen']);
    });

    test('ungültige Datei ändert nichts', () async {
      final repo =
          FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
      final scheduler = FakeReminderScheduler()..scheduled.add('old-1');

      await expectLater(
          restoreBackup(repo, scheduler, 'kaputt'), throwsFormatException);

      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.scheduled, {'old-1'});
      expect(repo.items.map((c) => c.id), ['old-1']);
    });

    test('ohne Erinnerungs-Planer wird nur der Stand ersetzt', () async {
      final repo =
          FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
      await restoreBackup(repo, null, backupFile());
      expect(repo.items, hasLength(2));
    });
  });
}
