import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/catalog.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import '../l10n/template_text.dart';
import 'adjust_sheet.dart';
import 'editor_screen.dart';
import 'format.dart';
import 'l10n.dart';
import 'rule_selector.dart';
import 'theme.dart';

typedef ChallengeStarted = Future<void> Function(ActiveChallenge challenge);

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.repository,
    this.onStarted,
    this.clock = DateTime.now,
    this.defaultReminder,
    this.pickDate = pickDateDefault,
  });

  final ChallengeRepository repository;

  /// Datumsauswahl für einen geplanten Start (im Test ersetzbar).
  final DatePick pickDate;

  /// Standard-Erinnerung aus den Einstellungen für Vorlagen ohne eigene Uhrzeit.
  final ReminderTime? defaultReminder;

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
        defaultReminder: defaultReminder,
        pickDate: pickDate,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.customChallenge),
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
              SliverAppBar.large(title: Text(context.l10n.navDiscover)),
              if (custom.isNotEmpty) ...[
                _SectionHeader(context.l10n.catalogMine),
                SliverList.builder(
                  itemCount: custom.length,
                  itemBuilder: (context, i) => card(custom[i]),
                ),
                _SectionHeader(context.l10n.catalogTemplates),
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
        defaultReminder: defaultReminder,
        clock: clock,
        pickDate: pickDate,
        onStart: (reminder, rule, startOn) async {
          final c =
              await repository.start(t, reminder, rule: rule, startOn: startOn);
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
        title: Text(context.l10n.deleteTemplateTitle),
        content: Text(context.l10n.deleteTemplateMessage(t.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteTemplate(t.id);
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.templateInUse),
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
                    Text(template.titleIn(context.l10n),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(kindLabelIn(context.l10n, template.kind),
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (running)
                Chip(
                  label: Text(context.l10n.runningChip),
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
    this.defaultReminder,
    required this.clock,
    required this.pickDate,
  });

  final ChallengeTemplate template;
  final bool running;
  final ReminderTime? defaultReminder;
  final Clock clock;
  final DatePick pickDate;
  final Future<void> Function(
      ReminderTime reminder, StreakRule rule, DateTime? startOn) onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late ReminderTime _reminder = defaultReminderFor(widget.template.id,
      fallback: widget.defaultReminder);
  StreakRule _rule = StreakRule.relaxed;
  bool _busy = false;

  /// Geplanter Starttag oder null für „heute“.
  DateTime? _startOn;

  Future<void> _pickStart() async {
    final today = dayOf(widget.clock());
    final picked = await widget.pickDate(
      context,
      initial: _startOn ?? today.add(const Duration(days: 1)),
      first: today,
      last: today.add(const Duration(days: maxPlanDays)),
    );
    if (picked == null || !mounted) return;
    setState(() => _startOn = dayOf(picked) == today ? null : dayOf(picked));
  }

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
    await widget.onStart(_reminder, _rule, _startOn);
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
            Text(t.titleIn(context.l10n),
                textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 8),
            Center(child: Chip(label: Text(kindLabelIn(context.l10n, t.kind)))),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(t.descriptionIn(context.l10n),
                  textAlign: TextAlign.center, style: text.bodyLarge),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(context.l10n.reminderLabel),
              trailing: Text(_reminder.toString(), style: text.titleMedium),
              onTap: widget.running ? null : _pickTime,
            ),
            if (!widget.running && canPlanStart(t.kind))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(context.l10n.startsLabel),
                trailing: Text(
                  switch (_startOn) {
                    final day? => formatDate(context.l10n, day, withYear: true),
                    null => context.l10n.navToday,
                  },
                  style: text.titleMedium,
                ),
                onTap: _pickStart,
              ),
            if (!widget.running && allowedRules(t.kind).isNotEmpty) ...[
              const SizedBox(height: 8),
              RuleSelector(
                value: _rule,
                allowed: allowedRules(t.kind),
                onChanged: (r) => setState(() => _rule = r),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.running || _busy ? null : _start,
              child: Text(widget.running
                  ? context.l10n.alreadyRunning
                  : _startOn != null
                      ? context.l10n.planChallenge
                      : context.l10n.startChallenge),
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
                      label: Text(context.l10n.commonEdit),
                    ),
                  if (widget.onDelete case final onDelete?)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.commonDelete),
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
