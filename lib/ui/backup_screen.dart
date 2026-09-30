import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/backup.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/csv_export.dart';
import '../domain/reminders.dart';
import '../domain/store_codec.dart';
import '../l10n/app_localizations.dart';
import '../l10n/background_texts.dart';
import 'format.dart';
import 'l10n.dart';

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

  /// Zeigt eine Meldung; der Text wird erst nach der `mounted`-Prüfung aus
  /// den Sprachpaketen geholt.
  void _show(String Function(AppLocalizations l10n) message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message(context.l10n))));
  }

  /// Führt [action] aus, sperrt solange die Knöpfe und meldet Dateifehler.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PlatformException {
      _show((l10n) => l10n.backupFileError);
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
        if (saved) _show((l10n) => l10n.backupSaved);
      });

  Future<void> _exportCsv() => _run(() async {
        final texts = csvTextsFor(context.l10n);
        final saved = await widget.files.save(
          name: exportFileName(widget.clock()),
          mimeType: 'text/csv',
          content: exportCsv(await _currentStore(), texts: texts),
        );
        if (saved) _show((l10n) => l10n.tableSaved);
      });

  Future<void> _restore() => _run(() async {
        final content = await widget.files.open();
        if (content == null || !mounted) return;
        final BackupSummary summary;
        try {
          summary = describeBackup(content);
        } on FormatException {
          _show((l10n) => l10n.backupInvalid);
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _RestoreDialog(summary: summary),
        );
        if (confirmed != true) return;
        await restoreBackup(widget.repository, widget.scheduler, content);
        _show((l10n) => l10n.backupRestored);
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(context.l10n.backupTitle)),
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
                            context.l10n.backupOnlyOnPhone,
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: context.l10n.backupSectionSave,
                  description: context.l10n.backupSectionSaveHint,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveBackup,
                    icon: const Icon(Icons.save_alt),
                    label: Text(context.l10n.backupSave),
                  ),
                ),
                _Section(
                  title: context.l10n.backupSectionExport,
                  description: context.l10n.backupSectionExportHint,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _exportCsv,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: Text(context.l10n.backupExportCsv),
                  ),
                ),
                _Section(
                  title: context.l10n.backupSectionRestore,
                  description: context.l10n.backupSectionRestoreHint,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: Text(context.l10n.backupRestore),
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
    final l10n = context.l10n;
    final date = formatDate(l10n, summary.exportedAt.toLocal(), withYear: true);
    return AlertDialog(
      title: Text(l10n.backupRestoreQuestion),
      content: Text(
        '${l10n.backupSavedOn(date)}\n'
        '• ${l10n.backupCountActive(summary.active)}\n'
        '• ${l10n.backupCountArchived(summary.archived)}\n'
        '• ${l10n.backupCountTemplates(summary.templates)}\n\n'
        '${l10n.backupReplaceWarning}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.backupReplace),
        ),
      ],
    );
  }
}
