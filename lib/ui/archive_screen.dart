import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/milestones.dart';
import '../domain/reminders.dart';
import 'detail_screen.dart';
import 'format.dart';
import 'theme.dart';

/// Abgeschlossene und beendete Challenges mit Rückblick.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.repository, this.scheduler});

  final ChallengeRepository repository;
  final ReminderScheduler? scheduler;

  Future<void> _restart(BuildContext context, ActiveChallenge c) async {
    final started = await repository.start(c.template, c.reminder, rule: c.rule);
    await scheduler?.schedule(started);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('„${c.template.title}“ läuft wieder')),
    );
  }

  Future<void> _reopen(BuildContext context, ActiveChallenge c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final reopened = await repository.reopen(c.id);
      await scheduler?.schedule(reopened);
      messenger.showSnackBar(SnackBar(
          content: Text('„${c.template.title}“ ist wieder unter Heute')));
    } on StateError {
      messenger.showSnackBar(SnackBar(
          content: Text(
              '„${c.template.title}“ läuft bereits – schließ die laufende zuerst ab.')));
    }
  }

  Future<void> _delete(BuildContext context, ActiveChallenge c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge löschen?'),
        content: Text(
            '„${c.template.title}“ und der ganze Verlauf werden endgültig gelöscht.'),
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
    if (confirmed == true) await repository.delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Erledigt')),
      body: StreamBuilder<ChallengeStore>(
        stream: repository.watchStore(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final items = [...snapshot.requireData.archived]..sort((a, b) =>
              (b.finishedOn ?? b.startedOn).compareTo(a.finishedOn ?? a.startedOn));
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text('Noch nichts abgeschlossen', style: text.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Geschaffte und beendete Challenges landen hier – mit Verlauf und bester Streak.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, i) => _ArchiveCard(
              challenge: items[i],
              onRestart: () => _restart(context, items[i]),
              onReopen: () => _reopen(context, items[i]),
              onDelete: () => _delete(context, items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.challenge,
    required this.onRestart,
    required this.onReopen,
    required this.onDelete,
  });

  final ActiveChallenge challenge;
  final VoidCallback onRestart;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final completed = challenge.status == ChallengeStatus.completed;
    final end = challenge.finishedOn ?? challenge.startedOn;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChallengeDetailScreen(challenge: challenge),
        )),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiBadge(challenge.template.emoji),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.template.title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDate(challenge.startedOn)} – ${formatDate(end)}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(completed ? 'Geschafft' : 'Beendet'),
                  avatar: Icon(
                    completed ? Icons.emoji_events : Icons.flag_outlined,
                    size: 18,
                  ),
                  backgroundColor: completed
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  visualDensity: VisualDensity.compact,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mehr',
                  onSelected: (action) =>
                      action == 'reopen' ? onReopen() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'reopen',
                      child: ListTile(
                        leading: Icon(Icons.undo),
                        title: Text('Wieder aufnehmen'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Löschen'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text('Beste Streak ${challenge.bestStreak}',
                          style: text.bodyMedium),
                      if (badges(challenge) case [..., final top])
                        Text('🏅 $top', style: text.bodyMedium),
                      Text(
                          '${challenge.doneDays} ${challenge.doneDays == 1 ? 'Tag' : 'Tage'} erledigt',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Nochmal starten'),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Kurze Feier, wenn eine Challenge ihr Ziel erreicht hat.
Future<void> showCelebration(BuildContext context, ActiveChallenge c) {
  final end = c.finishedOn ?? c.startedOn;
  final days = end.difference(dayOf(c.startedOn)).inDays + 1;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        icon: Text(c.template.emoji, style: const TextStyle(fontSize: 48)),
        title: const Text('Geschafft! 🏆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.template.title,
                textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 12),
            Text('Dauer: $days Tage · Beste Streak: ${c.bestStreak}',
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Du findest sie jetzt unter „Erledigt“.',
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Weiter'),
          ),
        ],
      );
    },
  );
}

/// Kurze Feier für einen erreichten Meilenstein.
Future<void> showMilestone(BuildContext context, ActiveChallenge c, int days) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Text('🏅', style: TextStyle(fontSize: 48)),
      title: const Text('Meilenstein erreicht'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$days Tage am Stück',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(c.template.title, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Weiter'),
        ),
      ],
    ),
  );
}
