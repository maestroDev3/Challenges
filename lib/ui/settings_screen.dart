import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/reminders.dart';
import '../domain/settings.dart';
import 'adjust_sheet.dart';
import 'backup_screen.dart';

/// Persönliche Einstellungen; erreichbar über das Zahnrad im Profil.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.repository,
    this.backupFiles,
    this.scheduler,
    this.clock = DateTime.now,
    this.pickTime = pickTimeDefault,
  });

  final SettingsRepository settings;
  final ChallengeRepository repository;

  /// Datei-Dialog für „Daten sichern“; ohne ihn fehlt der Eintrag.
  final BackupFiles? backupFiles;
  final ReminderScheduler? scheduler;
  final Clock clock;
  final TimePick pickTime;

  Future<void> _editName(BuildContext context, AppSettings current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: current.name),
    );
    if (name == null) return;
    await settings.save(current.copyWith(name: name.trim()));
  }

  Future<void> _pickReminder(BuildContext context, AppSettings current) async {
    final initial = current.defaultReminder ?? const ReminderTime(9, 0);
    final picked = await pickTime(
        context, TimeOfDay(hour: initial.hour, minute: initial.minute));
    if (picked == null) return;
    await settings.save(current.copyWith(
        defaultReminder: ReminderTime(picked.hour, picked.minute)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: StreamBuilder<AppSettings>(
        stream: settings.watch(),
        builder: (context, snapshot) {
          final current = snapshot.data;
          if (current == null) return const SizedBox.shrink();
          final reminder = current.defaultReminder;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _SectionTitle('Profil'),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Name'),
                subtitle: Text(
                    current.name.isEmpty ? 'Nicht gesetzt' : current.name),
                onTap: () => _editName(context, current),
              ),
              const _SectionTitle('Erinnerungen'),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: const Text('Standard-Erinnerung'),
                subtitle: Text(reminder == null
                    ? 'Je nach Challenge'
                    : reminder.toString()),
                trailing: reminder == null
                    ? null
                    : IconButton(
                        tooltip: 'Zurücksetzen',
                        icon: const Icon(Icons.close),
                        onPressed: () => settings.save(
                            current.copyWith(clearDefaultReminder: true)),
                      ),
                onTap: () => _pickReminder(context, current),
              ),
              const _SectionTitle('App'),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Intro beim Start zeigen'),
                subtitle: const Text('Leitsatz beim Öffnen der App'),
                value: current.showIntro,
                onChanged: (value) =>
                    settings.save(current.copyWith(showIntro: value)),
              ),
              if (backupFiles case final files?) ...[
                const _SectionTitle('Daten'),
                ListTile(
                  leading: Icon(Icons.save_outlined, color: scheme.primary),
                  title: const Text('Daten sichern'),
                  subtitle: const Text('Backup, Export, Wiederherstellen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BackupScreen(
                        repository: repository,
                        files: files,
                        scheduler: scheduler,
                        clock: clock,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(title,
          style: text.labelLarge?.copyWith(color: scheme.primary)),
    );
  }
}

/// Eingabe des Namens; liefert den Text oder null bei Abbruch.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Wie sollen wir dich nennen?'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
