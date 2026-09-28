import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/catalog.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import 'theme.dart';

typedef ChallengeStarted = Future<void> Function(ActiveChallenge challenge);

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.repository, this.onStarted});

  final ChallengeRepository repository;

  /// Wird nach dem Start aufgerufen (z. B. um die Erinnerung zu planen).
  final ChallengeStarted? onStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ActiveChallenge>>(
        stream: repository.watch(),
        builder: (context, snapshot) {
          final activeIds = {
            for (final c in snapshot.data ?? const <ActiveChallenge>[])
              c.template.id,
          };
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Entdecken')),
              SliverList.builder(
                itemCount: challengeCatalog.length,
                itemBuilder: (context, i) {
                  final t = challengeCatalog[i];
                  return _TemplateCard(
                    template: t,
                    running: activeIds.contains(t.id),
                    onTap: () => _openSheet(context, t, activeIds.contains(t.id)),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
      builder: (_) => _StartSheet(
        template: t,
        running: running,
        onStart: (reminder) async {
          final c = await repository.start(t, reminder);
          await onStarted?.call(c);
        },
      ),
    );
  }
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
  });

  final ChallengeTemplate template;
  final bool running;
  final Future<void> Function(ReminderTime reminder) onStart;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late ReminderTime _reminder = defaultReminderFor(widget.template.id);
  bool _busy = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked != null) {
      setState(() => _reminder = ReminderTime(picked.hour, picked.minute));
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await widget.onStart(_reminder);
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
            const SizedBox(height: 12),
            Text(t.description,
                textAlign: TextAlign.center, style: text.bodyLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Erinnerung'),
              trailing: Text(_reminder.toString(), style: text.titleMedium),
              onTap: widget.running ? null : _pickTime,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.running || _busy ? null : _start,
              child: Text(widget.running ? 'Läuft bereits' : 'Challenge starten'),
            ),
          ],
        ),
      ),
    );
  }
}
