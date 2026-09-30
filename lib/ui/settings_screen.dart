import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/language.dart';
import '../domain/reminders.dart';
import '../domain/settings.dart';
import 'adjust_sheet.dart';
import 'backup_screen.dart';
import 'l10n.dart';

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

  Future<void> _pickLanguage(BuildContext context, AppSettings current) async {
    final choice = await showDialog<({String? language})>(
      context: context,
      builder: (context) => _LanguageDialog(selected: current.language),
    );
    if (choice == null) return;
    await settings.save(choice.language == null
        ? current.copyWith(clearLanguage: true)
        : current.copyWith(language: choice.language));
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
                title: const Text('Uhrzeit für neue Challenges'),
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
              const _Hint(
                'Wird beim Starten einer neuen Challenge vorgeschlagen, wenn '
                'die Challenge keine eigene Uhrzeit hat. Laufende Challenges '
                'behalten ihre Uhrzeit – die änderst du über „Anpassen“.',
              ),
              const _SectionTitle('App'),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(context.l10n.settingsLanguage),
                subtitle: Text(switch (current.language) {
                  final language? => languageNames[language] ?? language,
                  null => context.l10n.languageSystem,
                }),
                onTap: () => _pickLanguage(context, current),
              ),
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

/// Auswahl der Sprache; liefert `(language: null)` für die Systemsprache
/// und `null` bei Abbruch.
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    Widget option(String? language, String label) => ListTile(
          title: Text(label),
          trailing: selected == language ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(context, (language: language)),
        );
    return SimpleDialog(
      title: Text(context.l10n.settingsLanguage),
      children: [
        option(null, context.l10n.languageSystem),
        for (final language in supportedLanguages)
          option(language, languageNames[language] ?? language),
      ],
    );
  }
}

/// Erklärender Text unter einer Einstellung.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
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
