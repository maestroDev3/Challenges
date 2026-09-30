import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:challenges/ui/backup_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backup_files.dart';
import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 5, 20, 15);

ActiveChallenge running(String id, String templateId) => ActiveChallenge(
      id: id,
      template: templateById(templateId)!,
      startedOn: DateTime.utc(2026, 9, 1),
      reminder: const ReminderTime(7, 0),
    ).checkIn(DateTime(2026, 9, 2), CheckInStatus.done);

String backupWithTwoRunning() => encodeBackup(
      ChallengeStore(
        active: [running('wake-1', 'wake-5am'), running('cold-1', 'cold-shower')],
        archived: [running('eye-1', 'eye-gaze').finish(DateTime(2026, 9, 10))],
        customTemplates: [
          ChallengeTemplate.custom(title: 'Lesen', kind: const JournalKind()),
        ],
      ),
      exportedAt: DateTime(2026, 9, 28, 21),
    );

Future<void> pumpBackup(
  WidgetTester tester, {
  required FakeChallengeRepository repo,
  required FakeBackupFiles files,
  FakeReminderScheduler? scheduler,
}) =>
    tester.pumpApp(BackupScreen(
      repository: repo,
      files: files,
      scheduler: scheduler,
      clock: () => now,
    ));

void main() {
  testWidgets('„Heute“ hat kein ⋮-Menü mehr (Daten sichern liegt in den Einstellungen)',
      (tester) async {
    await tester.pumpApp(TodayScreen(
      repository: FakeChallengeRepository(),
      onDiscover: () {},
      clock: () => now,
    ));
    expect(find.byTooltip('Weitere Optionen'), findsNothing);
    expect(find.text('Daten sichern'), findsNothing);
  });

  testWidgets('Backup speichern schreibt eine JSON-Datei mit Datum im Namen',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [running('wake-1', 'wake-5am')]);
    final files = FakeBackupFiles();
    await pumpBackup(tester, repo: repo, files: files);
    await tester.tap(find.text('Backup speichern'));
    await tester.pumpAndSettle();

    final saved = files.saved.single;
    expect(saved.name, 'ritual-backup-2026-10-05.json');
    expect(saved.mimeType, 'application/json');
    expect(decodeBackup(saved.content).store.active.single.id, 'wake-1');
    expect(find.text('Backup gespeichert'), findsOneWidget);
  });

  testWidgets('Abbruch beim Speichern zeigt keine Meldung', (tester) async {
    await pumpBackup(tester,
        repo: FakeChallengeRepository(),
        files: FakeBackupFiles(cancelSave: true));
    await tester.tap(find.text('Backup speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Backup gespeichert'), findsNothing);
  });

  testWidgets('CSV-Export speichert eine Tabelle', (tester) async {
    final files = FakeBackupFiles();
    await pumpBackup(tester,
        repo: FakeChallengeRepository(initial: [running('wake-1', 'wake-5am')]),
        files: files);
    await tester.tap(find.text('Als Tabelle exportieren (CSV)'));
    await tester.pumpAndSettle();

    final saved = files.saved.single;
    expect(saved.name, 'ritual-export-2026-10-05.csv');
    expect(saved.mimeType, 'text/csv');
    expect(saved.content, startsWith('﻿Datum;Challenge;Status'));
    expect(find.text('Tabelle gespeichert'), findsOneWidget);
  });

  testWidgets('Wiederherstellen fragt nach und ersetzt erst nach „Ersetzen“',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
    final scheduler = FakeReminderScheduler();
    await pumpBackup(tester,
        repo: repo,
        files: FakeBackupFiles(toOpen: backupWithTwoRunning()),
        scheduler: scheduler);
    await tester.tap(find.text('Backup wiederherstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Backup wiederherstellen?'), findsOneWidget);
    expect(find.textContaining('28.09.2026'), findsOneWidget);
    expect(find.textContaining('2 laufende'), findsOneWidget);
    expect(find.textContaining('1 abgeschlossene'), findsOneWidget);
    expect(find.textContaining('1 eigene Vorlage'), findsOneWidget);
    expect(repo.items.single.id, 'old-1');

    await tester.tap(find.text('Ersetzen'));
    await tester.pumpAndSettle();
    expect(repo.items.map((c) => c.id), ['wake-1', 'cold-1']);
    expect(scheduler.cancelled, ['old-1']);
    expect(scheduler.scheduled, {'wake-1', 'cold-1'});
    expect(find.text('Backup wiederhergestellt'), findsOneWidget);
  });

  testWidgets('„Abbrechen“ lässt alles unverändert', (tester) async {
    final repo = FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
    await pumpBackup(tester,
        repo: repo, files: FakeBackupFiles(toOpen: backupWithTwoRunning()));
    await tester.tap(find.text('Backup wiederherstellen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.items.single.id, 'old-1');
    expect(find.text('Backup wiederhergestellt'), findsNothing);
  });

  testWidgets('ungültige Datei zeigt Fehlermeldung und ändert nichts',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
    await pumpBackup(tester,
        repo: repo, files: FakeBackupFiles(toOpen: '{"format":"etwas anderes"}'));
    await tester.tap(find.text('Backup wiederherstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Diese Datei ist kein gültiges Ritual-Backup.'),
        findsOneWidget);
    expect(find.text('Backup wiederherstellen?'), findsNothing);
    expect(repo.items.single.id, 'old-1');
  });

  testWidgets('Abbruch der Dateiauswahl ändert nichts', (tester) async {
    final repo = FakeChallengeRepository(initial: [running('old-1', 'no-sugar')]);
    await pumpBackup(tester, repo: repo, files: FakeBackupFiles());
    await tester.tap(find.text('Backup wiederherstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Backup wiederherstellen?'), findsNothing);
    expect(repo.items.single.id, 'old-1');
  });
}
