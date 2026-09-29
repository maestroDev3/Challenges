import 'challenge_repository.dart';
import 'reminders.dart';
import 'store_codec.dart';

/// Eckdaten einer Backup-Datei für die Sicherheitsabfrage vor dem Ersetzen.
class BackupSummary {
  const BackupSummary({
    required this.active,
    required this.archived,
    required this.templates,
    required this.exportedAt,
  });

  final int active;
  final int archived;
  final int templates;
  final DateTime exportedAt;
}

/// Liest die Eckdaten; ungültige Datei → [FormatException].
BackupSummary describeBackup(String content) {
  final backup = decodeBackup(content);
  return BackupSummary(
    active: backup.store.active.length,
    archived: backup.store.archived.length,
    templates: backup.store.customTemplates.length,
    exportedAt: backup.exportedAt,
  );
}

/// Ersetzt den kompletten Stand durch das Backup. Die Datei wird zuerst
/// vollständig gelesen, damit eine kaputte Datei nichts verändert; danach
/// werden alte Erinnerungen storniert und die neuen geplant.
Future<void> restoreBackup(
  ChallengeRepository repository,
  ReminderScheduler? scheduler,
  String content,
) async {
  final backup = decodeBackup(content);
  if (scheduler != null) {
    for (final challenge in await repository.active()) {
      await scheduler.cancel(challenge);
      await scheduler.clearSession(challenge);
    }
  }
  await repository.replaceAll(backup.store);
  if (scheduler != null) {
    for (final challenge in backup.store.active) {
      await scheduler.schedule(challenge);
    }
  }
}

/// Dateiname der Sicherung, z. B. `ritual-backup-2026-09-29.json`; das Datum
/// im Namen hilft, mehrere Sicherungen auseinanderzuhalten.
String backupFileName(DateTime now) => 'ritual-backup-${_isoDate(now)}.json';

/// Dateiname der Tabelle, z. B. `ritual-export-2026-09-29.csv`.
String exportFileName(DateTime now) => 'ritual-export-${_isoDate(now)}.csv';

String _isoDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}
