import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/backup.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/csv_export.dart';
import '../domain/reminders.dart';
import '../domain/store_codec.dart';
import 'format.dart';

/// Sichern, Exportieren und Wiederherstellen aller Daten. Die Daten liegen nur
/// auf dem Handy – diese Seite ist der Weg, sie bei Verlust oder Handywechsel
/// nicht zu verlieren.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.repository,
    required this.files,
    this.scheduler,
    this.clock = DateTime.now,
  });

  final ChallengeRepository repository;
  final BackupFiles files;
  final ReminderScheduler? scheduler;
  final Clock clock;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  /// Verhindert, dass zwei Dateidialoge gleichzeitig geöffnet werden.
  bool _busy = false;

  Future<ChallengeStore> _currentStore() async {
    final repository = widget.repository;
    return ChallengeStore(
      active: await repository.active(),
      archived: await repository.archived(),
      customTemplates: await repository.customTemplates(),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Führt [action] aus, sperrt solange die Knöpfe und meldet Dateifehler.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PlatformException {
      _show('Die Datei konnte nicht gelesen oder geschrieben werden.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBackup() => _run(() async {
        final now = widget.clock();
        final saved = await widget.files.save(
          name: backupFileName(now),
          mimeType: 'application/json',
          content: encodeBackup(await _currentStore(), exportedAt: now),
        );
        if (saved) _show('Backup gespeichert');
      });

  Future<void> _exportCsv() => _run(() async {
        final saved = await widget.files.save(
          name: exportFileName(widget.clock()),
          mimeType: 'text/csv',
          content: exportCsv(await _currentStore()),
        );
        if (saved) _show('Tabelle gespeichert');
      });

  Future<void> _restore() => _run(() async {
        final content = await widget.files.open();
        if (content == null || !mounted) return;
        final BackupSummary summary;
        try {
          summary = describeBackup(content);
        } on FormatException {
          _show('Diese Datei ist kein gültiges Ritual-Backup.');
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _RestoreDialog(summary: summary),
        );
        if (confirmed != true) return;
        await restoreBackup(widget.repository, widget.scheduler, content);
        _show('Backup wiederhergestellt');
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Daten sichern')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.list(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Deine Daten liegen nur auf diesem Handy. '
                            'Speichere regelmäßig ein Backup, z. B. in Google '
                            'Drive – so ist bei Verlust oder Handywechsel '
                            'nichts verloren.',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Sichern',
                  description: 'Alle Challenges, Check-ins und eigenen Vorlagen '
                      'in einer Datei. Du wählst selbst, wo sie landet.',
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveBackup,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Backup speichern'),
                  ),
                ),
                _Section(
                  title: 'Exportieren',
                  description: 'Alle Check-ins als Tabelle, z. B. für Excel '
                      'oder Google Sheets. Nicht zum Wiederherstellen.',
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _exportCsv,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Als Tabelle exportieren (CSV)'),
                  ),
                ),
                _Section(
                  title: 'Wiederherstellen',
                  description: 'Ersetzt deinen aktuellen Stand komplett durch '
                      'den Stand aus einer Backup-Datei.',
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Backup wiederherstellen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(description, style: text.bodyMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Sicherheitsabfrage vor dem Ersetzen; liefert `true` bei „Ersetzen“.
class _RestoreDialog extends StatelessWidget {
  const _RestoreDialog({required this.summary});

  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final date = formatDate(summary.exportedAt.toLocal(), withYear: true);
    return AlertDialog(
      title: const Text('Backup wiederherstellen?'),
      content: Text(
        'Gesichert am $date:\n'
        '• ${count(summary.active, 'laufende Challenge', 'laufende Challenges')}\n'
        '• ${count(summary.archived, 'abgeschlossene Challenge', 'abgeschlossene Challenges')}\n'
        '• ${count(summary.templates, 'eigene Vorlage', 'eigene Vorlagen')}\n\n'
        'Dein aktueller Stand wird dabei vollständig ersetzt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ersetzen'),
        ),
      ],
    );
  }
}
