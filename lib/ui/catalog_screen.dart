import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/catalog.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import 'editor_screen.dart';
import 'rule_selector.dart';
import 'theme.dart';

typedef ChallengeStarted = Future<void> Function(ActiveChallenge challenge);

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.repository,
    this.onStarted,
    this.clock = DateTime.now,
  });

  final ChallengeRepository repository;

  /// Wird nach dem Start aufgerufen (z. B. um die Erinnerung zu planen).
  final ChallengeStarted? onStarted;
  final Clock clock;

  void _openEditor(BuildContext context, {ChallengeTemplate? initial}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChallengeEditorScreen(
        repository: repository,
        initial: initial,
        clock: clock,
        onStarted: onStarted,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Eigene Challenge'),
      ),
      body: StreamBuilder<ChallengeStore>(
        stream: repository.watchStore(),
        builder: (context, snapshot) {
          final store = snapshot.data ?? const ChallengeStore();
          final activeIds = {for (final c in store.active) c.template.id};
          final custom = store.customTemplates;
          Widget card(ChallengeTemplate t) => _TemplateCard(
                template: t,
                running: activeIds.contains(t.id),
                onTap: () => _openSheet(context, t, activeIds.contains(t.id)),
              );
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Entdecken')),
              if (custom.isNotEmpty) ...[
                const _SectionHeader('Meine Challenges'),
                SliverList.builder(
                  itemCount: custom.length,
                  itemBuilder: (context, i) => card(custom[i]),
                ),
                const _SectionHeader('Vorlagen'),
              ],
              SliverList.builder(
                itemCount: challengeCatalog.length,
                itemBuilder: (context, i) => card(challengeCatalog[i]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSheet(
      BuildContext context, ChallengeTemplate t, bool running) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _StartSheet(
        template: t,
        running: running,
        onStart: (reminder, rule) async {
          final c = await repository.start(t, reminder, rule: rule);
          await onStarted?.call(c);
        },
        onEdit: t.isCustom
            ? () {
                Navigator.of(sheetContext).pop();
                _openEditor(context, initial: t);
              }
            : null,
        onDelete: t.isCustom
            ? () async {
                Navigator.of(sheetContext).pop();
                await _confirmDelete(context, t);
              }
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ChallengeTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vorlage löschen?'),
        content: Text('„${t.title}“ wird endgültig gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteTemplate(t.id);
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Läuft gerade – schließ die Challenge zuerst ab.'),
      ));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.running,
    required this.onTap,
  });

  final ChallengeTemplate template;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              EmojiBadge(template.emoji),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(template.kindLabel,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (running)
                Chip(
                  label: const Text('läuft'),
                  backgroundColor: scheme.secondaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartSheet extends StatefulWidget {
  const _StartSheet({
    required this.template,
    required this.running,
    required this.onStart,
    this.onEdit,
    this.onDelete,
  });

  final ChallengeTemplate template;
  final bool running;
  final Future<void> Function(ReminderTime reminder, StreakRule rule) onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late ReminderTime _reminder = defaultReminderFor(widget.template.id);
  StreakRule _rule = StreakRule.relaxed;
  bool _busy = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked != null && mounted) {
      setState(() => _reminder = ReminderTime(picked.hour, picked.minute));
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await widget.onStart(_reminder, _rule);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: EmojiBadge(t.emoji, size: 72)),
            const SizedBox(height: 16),
            Text(t.title,
                textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 8),
            Center(child: Chip(label: Text(t.kindLabel))),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(t.description,
                  textAlign: TextAlign.center, style: text.bodyLarge),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Erinnerung'),
              trailing: Text(_reminder.toString(), style: text.titleMedium),
              onTap: widget.running ? null : _pickTime,
            ),
            if (!widget.running) ...[
              const SizedBox(height: 8),
              RuleSelector(
                value: _rule,
                onChanged: (r) => setState(() => _rule = r),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.running || _busy ? null : _start,
              child: Text(widget.running ? 'Läuft bereits' : 'Challenge starten'),
            ),
            if (widget.onEdit != null || widget.onDelete != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.onEdit case final onEdit?)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Bearbeiten'),
                    ),
                  if (widget.onDelete case final onDelete?)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Löschen'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
