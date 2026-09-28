import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.repository,
    required this.onDiscover,
    this.clock = DateTime.now,
    this.onStopped,
  });

  final ChallengeRepository repository;
  final VoidCallback onDiscover;
  final Clock clock;
  final Future<void> Function(ActiveChallenge challenge)? onStopped;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ActiveChallenge>>(
        stream: repository.watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <ActiveChallenge>[];
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Heute')),
              if (snapshot.hasData && items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onDiscover: onDiscover),
                )
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => ChallengeCard(
                    challenge: items[i],
                    today: clock(),
                    onSave: repository.save,
                    onStop: (c) async {
                      await repository.stop(c.id);
                      await onStopped?.call(c);
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Noch keine Challenge aktiv', style: text.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Such dir eine Challenge aus und bau deine erste Streak auf.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDiscover,
            child: const Text('Challenge finden'),
          ),
        ],
      ),
    );
  }
}

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.today,
    required this.onSave,
    required this.onStop,
  });

  final ActiveChallenge challenge;
  final DateTime today;
  final Future<void> Function(ActiveChallenge) onSave;
  final Future<void> Function(ActiveChallenge) onStop;

  Future<void> _done(BuildContext context) async {
    switch (challenge.kind) {
      case JournalKind():
        final note = await _ask(context,
            title: 'Welche Ausrede hattest du heute?', hint: 'Ehrlich sein …');
        if (note == null || note.trim().isEmpty) return;
        await onSave(
            challenge.checkIn(today, CheckInStatus.done, note: note.trim()));
      case WeeklyGoalKind():
        final raw = await _ask(context,
            title: 'Wie viele Minuten warst du draußen?',
            hint: 'Minuten',
            number: true);
        final minutes = int.tryParse(raw ?? '');
        if (minutes == null || minutes <= 0) return;
        await onSave(
            challenge.checkIn(today, CheckInStatus.done, minutes: minutes));
      default:
        await onSave(challenge.checkIn(today, CheckInStatus.done));
    }
  }

  Future<void> _missed() =>
      onSave(challenge.checkIn(today, CheckInStatus.missed));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = challenge.checkInOn(today)?.status;
    final progress = challenge.progress(today);
    final isWeekly = challenge.kind is WeeklyGoalKind;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProgressRing(emoji: challenge.template.emoji, value: progress),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.template.title, style: text.titleMedium),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          Text(
                            '🔥 ${challenge.currentStreak(today)}',
                            style: text.titleSmall,
                          ),
                          if (_progressLabel() case final label?)
                            Text(label,
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) => onStop(challenge),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'stop', child: Text('Challenge beenden')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WeekRow(days: challenge.week(today)),
            const SizedBox(height: 12),
            if (challenge.isCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text('Geschafft! 🏆',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(color: scheme.primary)),
              ),
            if (status != null && !isWeekly)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(
                  status == CheckInStatus.done
                      ? 'Heute erledigt'
                      : 'Heute nicht geschafft',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Nicht erledigt',
                      icon: Icons.close_rounded,
                      selected: status == CheckInStatus.missed,
                      onPressed: _missed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Erledigt',
                      icon: Icons.check_rounded,
                      selected: status == CheckInStatus.done,
                      onPressed: () => _done(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _progressLabel() => switch (challenge.kind) {
        DailyKind(days: final d?) => '${challenge.doneDays}/$d',
        WeeklyGoalKind(minutes: final m) =>
          '${challenge.minutesInWeek(today)}/$m min',
        OneTimeKind() => challenge.isCompleted ? null : 'einmalig',
        _ => null,
      };
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.emoji, required this.value});

  final String emoji;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value ?? 0,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.days});

  final List<DayStatus> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (i, d) in days.indexed)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (d) {
                  DayStatus.done => scheme.primary,
                  DayStatus.missed => scheme.errorContainer,
                  DayStatus.open => scheme.surfaceContainerHighest,
                },
                border: i == days.length - 1
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: switch (d) {
                DayStatus.done =>
                  Icon(Icons.check, size: 16, color: scheme.onPrimary),
                DayStatus.missed => Icon(Icons.close,
                    size: 16, color: scheme.onErrorContainer),
                DayStatus.open => null,
              },
            ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
    return selected
        ? FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label))
        : OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label));
  }
}

Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String hint,
  bool number = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: number ? 1 : 4,
        minLines: 1,
        keyboardType: number ? TextInputType.number : TextInputType.multiline,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}
