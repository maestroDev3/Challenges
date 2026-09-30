import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/milestones.dart';
import '../domain/reminders.dart';
import '../l10n/template_text.dart';
import 'detail_screen.dart';
import 'format.dart';
import 'l10n.dart';
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
      SnackBar(
          content: Text(context.l10n
              .archiveRunningAgain(c.template.titleIn(context.l10n)))),
    );
  }

  Future<void> _reopen(BuildContext context, ActiveChallenge c) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final reopened = await repository.reopen(c.id);
      await scheduler?.schedule(reopened);
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.archiveBackInToday(c.template.titleIn(l10n)))));
    } on StateError {
      messenger.showSnackBar(SnackBar(
          content:
              Text(l10n.archiveAlreadyRunning(c.template.titleIn(l10n)))));
    }
  }

  Future<void> _delete(BuildContext context, ActiveChallenge c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteChallengeTitle),
        content: Text(context.l10n
            .archiveDeleteMessage(c.template.titleIn(context.l10n))),
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
    if (confirmed == true) await repository.delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.archiveTitle)),
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
                    Text(context.l10n.archiveEmptyTitle,
                        style: text.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.archiveEmptyBody,
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
                      Text(challenge.template.titleIn(context.l10n),
                          style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDate(context.l10n, challenge.startedOn)} – '
                        '${formatDate(context.l10n, end)}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(completed
                      ? context.l10n.resultDone
                      : context.l10n.archiveEnded),
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
                  tooltip: context.l10n.commonMore,
                  onSelected: (action) =>
                      action == 'reopen' ? onReopen() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reopen',
                      child: ListTile(
                        leading: const Icon(Icons.undo),
                        title: Text(context.l10n.archiveReopen),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: Text(context.l10n.commonDelete),
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
                      Text(context.l10n.archiveBestStreak(challenge.bestStreak),
                          style: text.bodyMedium),
                      if (badges(challenge) case [..., final top])
                        Text('🏅 $top', style: text.bodyMedium),
                      Text(
                          context.l10n.archiveDaysDone(challenge.doneDays),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay),
                  label: Text(context.l10n.archiveRestart),
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
        title: Text(context.l10n.completedBanner),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.template.titleIn(context.l10n),
                textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 12),
            Text(
                context.l10n.celebrationDuration(
                    context.l10n.daysCount(days), c.bestStreak),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(context.l10n.celebrationWhere,
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonContinue),
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
      title: Text(context.l10n.milestoneTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.milestoneDays(days),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(c.template.titleIn(context.l10n), textAlign: TextAlign.center),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonContinue),
        ),
      ],
    ),
  );
}
