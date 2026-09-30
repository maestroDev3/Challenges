import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:challenges/ui/backup_screen.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:challenges/ui/profile_screen.dart';
import 'package:challenges/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backup_files.dart';
import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 5, 20, 15);
const english = Locale('en');

ActiveChallenge running(String id, String templateId) => ActiveChallenge(
      id: id,
      template: templateById(templateId)!,
      startedOn: DateTime.utc(2026, 9, 1),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  testWidgets('Entdecken auf Englisch', (tester) async {
    await tester.pumpApp(
      CatalogScreen(repository: FakeChallengeRepository()),
      locale: english,
      size: const Size(900, 3200),
    );
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Custom challenge'), findsOneWidget);
    await tester.tap(find.text('Um 5 Uhr aufstehen'));
    await tester.pumpAndSettle();
    expect(find.text('Start challenge'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
  });

  testWidgets('Editor auf Englisch', (tester) async {
    await tester.pumpApp(
      ChallengeEditorScreen(
          repository: FakeChallengeRepository(), clock: () => now),
      locale: english,
      size: const Size(900, 3200),
    );
    expect(find.text('Custom challenge'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('Relaxed'), findsOneWidget);
    expect(find.text('Joker'), findsOneWidget);
    expect(find.text('Save & start'), findsOneWidget);
  });

  testWidgets('Profil auf Englisch', (tester) async {
    await tester.pumpApp(
      ProfileScreen(
        repository:
            FakeChallengeRepository(initial: [running('w', 'wake-5am')]),
        settings: FakeSettingsRepository(),
        onOpenSettings: () {},
      ),
      locale: english,
    );
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Days done'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    // Der Leitsatz bleibt in allen Sprachen Englisch.
    expect(find.text('Sacrifice the moment. Evolve the future.'), findsOneWidget);
  });

  testWidgets('Einstellungen auf Englisch', (tester) async {
    await tester.pumpApp(
      SettingsScreen(
        settings: FakeSettingsRepository(),
        repository: FakeChallengeRepository(),
        backupFiles: FakeBackupFiles(),
      ),
      locale: english,
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Time for new challenges'), findsOneWidget);
    expect(find.text('Depends on the challenge'), findsOneWidget);
    expect(find.text('Show intro on start'), findsOneWidget);
    expect(find.text('Back up data'), findsOneWidget);
  });

  testWidgets('Daten sichern auf Englisch, mit Mehrzahl in der Abfrage',
      (tester) async {
    final backup = encodeBackup(
      ChallengeStore(
        active: [running('a', 'wake-5am'), running('b', 'cold-shower')],
        archived: [running('c', 'eye-gaze').finish(DateTime(2026, 9, 10))],
        customTemplates: [
          ChallengeTemplate.custom(title: 'Lesen', kind: const JournalKind()),
        ],
      ),
      exportedAt: DateTime(2026, 9, 28, 21),
    );
    await tester.pumpApp(
      BackupScreen(
        repository: FakeChallengeRepository(),
        files: FakeBackupFiles(toOpen: backup),
        clock: () => now,
      ),
      locale: english,
    );
    expect(find.text('Save backup'), findsOneWidget);
    expect(find.text('Export as table (CSV)'), findsOneWidget);
    await tester.tap(find.text('Restore backup'));
    await tester.pumpAndSettle();
    expect(find.text('Restore backup?'), findsOneWidget);
    expect(find.textContaining('2 running challenges'), findsOneWidget);
    expect(find.textContaining('1 finished challenge'), findsOneWidget);
    expect(find.textContaining('1 custom template'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
  });
}
