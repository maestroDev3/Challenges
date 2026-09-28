import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/milestones.dart';
import '../domain/reminders.dart';
import 'archive_screen.dart';
import 'detail_screen.dart';
import 'format.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.repository,
    required this.onDiscover,
    this.clock = DateTime.now,
    this.scheduler,
  });

  final ChallengeRepository repository;
  final VoidCallback onDiscover;
  final Clock clock;
  final ReminderScheduler? scheduler;

  /// Speichert und archiviert automatisch, wenn das Ziel erreicht ist.
  Future<void> _save(BuildContext context, ActiveChallenge c) async {
    final before = await repository.byId(c.id);
    await repository.save(c);
    if (c.shouldAutoFinish(clock())) {
      final done = await repository.finish(c.id);
      await scheduler?.cancel(c);
      if (done != null && context.mounted) await showCelebration(context, done);
      return;
    }
    final milestone = before == null ? null : milestoneReached(before, c);
    if (milestone != null && context.mounted) {
      await showMilestone(context, c, milestone);
    }
  }

  /// Pausieren/Fortsetzen: Erinnerung neu planen (erster Termin nach der Pause).
  Future<void> _reschedule(ActiveChallenge c) async {
    await repository.save(c);
    await scheduler?.schedule(c);
  }

  Future<void> _finish(ActiveChallenge c) async {
    await repository.finish(c.id);
    await scheduler?.cancel(c);
  }

  Future<void> _delete(BuildContext context, ActiveChallenge c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge löschen?'),
        content: Text(
            '„${c.template.title}“ und der ganze Verlauf werden endgültig gelöscht. '
            'Zum Aufbewahren lieber „Abschließen“.'),
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
    await repository.delete(c.id);
    await scheduler?.cancel(c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ActiveChallenge>>(
        stream: repository.watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <ActiveChallenge>[];
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Heute'),
                actions: [
                  IconButton(
                    tooltip: 'Erledigt',
                    icon: const Icon(Icons.emoji_events_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArchiveScreen(
                          repository: repository,
                          scheduler: scheduler,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (snapshot.hasData && items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onDiscover: onDiscover),
                )
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => _Ticker(
                    // Nur laufende Countdowns brauchen eine Live-Anzeige.
                    active: items[i].windowStartedAt != null,
                    clock: clock,
                    builder: (now) => ChallengeCard(
                      challenge: items[i],
                      today: now,
                      onSave: (c) => _save(context, c),
                      onFinish: _finish,
                      onDelete: (c) => _delete(context, c),
                      onPauseChanged: _reschedule,
                    ),
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
    required this.onFinish,
    required this.onDelete,
    required this.onPauseChanged,
  });

  final ActiveChallenge challenge;
  final DateTime today;
  final Future<void> Function(ActiveChallenge) onSave;
  final Future<void> Function(ActiveChallenge) onFinish;
  final Future<void> Function(ActiveChallenge) onDelete;

  /// Challenge wurde pausiert oder fortgesetzt.
  final Future<void> Function(ActiveChallenge) onPauseChanged;

  Future<void> _pause(BuildContext context) async {
    final t = dayOf(today);
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Pausieren'),
              subtitle: Text(
                  'Für Krankheit oder Urlaub: Pausentage brechen die Streak nicht, Erinnerungen ruhen.'),
            ),
            for (final (days, label) in const [
              (1, 'Nur heute'),
              (3, '3 Tage'),
              (7, '1 Woche'),
            ])
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: Text(label),
                onTap: () => Navigator.pop(context, days),
              ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Bis Datum …'),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    DateTime? until;
    if (choice == 0) {
      until = await showDatePicker(
        context: context,
        initialDate: t.add(const Duration(days: 3)),
        firstDate: t,
        lastDate: t.add(const Duration(days: 90)),
      );
    } else {
      until = t.add(Duration(days: choice - 1));
    }
    if (until == null) return;
    await onPauseChanged(challenge.pause(from: t, until: until));
  }

  Future<void> _correct(BuildContext context, DateTime day) async {
    final minutesKind = challenge.kind is WeeklyGoalKind &&
        (challenge.kind as WeeklyGoalKind).unit == WeeklyUnit.minutes;
    final choice = await showModalBottomSheet<_DayChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(formatWeekdayDate(day)),
              subtitle: const Text('Tag nachtragen oder korrigieren'),
            ),
            ListTile(
              leading: const Icon(Icons.check_rounded),
              title: const Text('Erledigt'),
              onTap: () => Navigator.pop(context, _DayChoice.done),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Nicht erledigt'),
              onTap: () => Navigator.pop(context, _DayChoice.missed),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('Leer'),
              onTap: () => Navigator.pop(context, _DayChoice.empty),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    int? minutes;
    if (choice == _DayChoice.done && minutesKind) {
      minutes = int.tryParse(await _ask(context,
              title: 'Wie viele Minuten?', hint: 'Minuten', number: true) ??
          '');
      if (minutes == null || minutes <= 0) return;
    }
    await onSave(challenge.correct(
      day,
      switch (choice) {
        _DayChoice.done => CheckInStatus.done,
        _DayChoice.missed => CheckInStatus.missed,
        _DayChoice.empty => null,
      },
      today: today,
      minutes: minutes,
    ));
  }

  Future<void> _done(BuildContext context) async {
    switch (challenge.kind) {
      case JournalKind():
        final note = await _ask(context,
            title: 'Welche Ausrede hattest du heute?', hint: 'Ehrlich sein …');
        if (note == null || note.trim().isEmpty) return;
        await onSave(
            challenge.checkIn(today, CheckInStatus.done, note: note.trim()));
      case WeeklyGoalKind(unit: WeeklyUnit.minutes):
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
    final progress = challenge.windowProgress(today) ?? challenge.progress(today);
    final kind = challenge.kind;
    final window = kind is OneTimeKind && !challenge.isCompleted
        ? (challenge.windowStartedAt == null
            ? _WindowState.idle
            : challenge.windowEnded(today)
                ? _WindowState.ended
                : _WindowState.running)
        : null;
    final isWeekly = kind is WeeklyGoalKind && kind.unit == WeeklyUnit.minutes;
    final pausedUntil = challenge.pausedUntil(today);
    final paused = pausedUntil != null;
    final jokers = challenge.rule == StreakRule.joker ? challenge.jokers(today) : null;
    final attempt = challenge.attempt(today);

    return Card(
      color: paused ? scheme.surfaceContainerLowest : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChallengeDetailScreen(
                  challenge: challenge,
                  clock: () => today,
                ),
              )),
              child: Row(
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
                          if (jokers != null)
                            Tooltip(
                              message: 'Joker',
                              child: Text('🛡️ $jokers', style: text.titleSmall),
                            ),
                          if (attempt > 1)
                            Text('Versuch $attempt',
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mehr',
                  onSelected: (action) => switch (action) {
                    'pause' => _pause(context),
                    'finish' => onFinish(challenge),
                    _ => onDelete(challenge),
                  },
                  itemBuilder: (_) => [
                    if (!paused)
                      const PopupMenuItem(
                        value: 'pause',
                        child: ListTile(
                          leading: Icon(Icons.pause_circle_outline),
                          title: Text('Pausieren'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'finish',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Abschließen'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
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
            ),
            const SizedBox(height: 12),
            _WeekRow(
              days: challenge.week(today),
              today: dayOf(today),
              firstDay: dayOf(challenge.startedOn),
              onTapDay: (day) => _correct(context, day),
            ),
            if (challenge.template.steps.isNotEmpty && !paused)
              _Checklist(
                steps: challenge.template.steps,
                done: challenge.stepsDoneOn(today),
                onToggle: (i) => onSave(challenge.toggleStep(today, i)),
              ),
            const SizedBox(height: 12),
            if (challenge.isCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text('Geschafft! 🏆',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(color: scheme.primary)),
              ),
            if (paused)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pausiert bis ${formatDate(pausedUntil)}',
                        style: text.titleSmall,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => onPauseChanged(challenge.resume(today)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Fortsetzen'),
                    ),
                  ],
                ),
              ),
            if (!paused && window == _WindowState.idle)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () =>
                      onPauseChanged(challenge.startWindow(today)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Jetzt starten'),
                ),
              ),
            if (!paused && window == _WindowState.running)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'noch ${formatRemaining(challenge.remaining(today) ?? Duration.zero)} h',
                        style: text.titleLarge?.copyWith(color: scheme.primary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onPauseChanged(challenge.cancelWindow()),
                      child: const Text('Abbrechen'),
                    ),
                  ],
                ),
              ),
            if (!paused && window == _WindowState.ended)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text('Geschafft?',
                    textAlign: TextAlign.center, style: text.titleLarge),
              ),
            if (!paused && status != null && !isWeekly)
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
            if (!paused &&
                (window == null || window == _WindowState.ended))
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
        DailyKind(days: final d?) =>
          '${((challenge.progress(today) ?? 0) * d).round()}/$d',
        WeeklyGoalKind(unit: WeeklyUnit.times, target: final n) =>
          '${challenge.doneDaysInWeek(today)}/$n×',
        WeeklyGoalKind(target: final m) =>
          '${challenge.minutesInWeek(today)}/$m min',
        OneTimeKind() => challenge.isCompleted || challenge.windowStartedAt != null
            ? null
            : 'einmalig',
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
  const _WeekRow({
    required this.days,
    required this.today,
    required this.firstDay,
    required this.onTapDay,
  });

  final List<DayStatus> days;
  final DateTime today;
  final DateTime firstDay;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (i, d) in days.indexed)
            _Dot(
              key: Key('day-$i'),
              day: today.subtract(Duration(days: days.length - 1 - i)),
              firstDay: firstDay,
              onTap: onTapDay,
              child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (d) {
                  DayStatus.done => scheme.primary,
                  DayStatus.missed => scheme.errorContainer,
                  DayStatus.open => scheme.surfaceContainerHighest,
                  DayStatus.paused => scheme.tertiaryContainer,
                  DayStatus.joker => scheme.secondaryContainer,
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
                DayStatus.paused => Icon(Icons.pause,
                    size: 14, color: scheme.onTertiaryContainer),
                DayStatus.joker => Icon(Icons.shield_outlined,
                    size: 14, color: scheme.primary),
              },
            ),
            ),
        ],
      ),
    );
  }
}

/// Tägliche Schritte zum Abhaken (z. B. Morgenroutine).
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.steps,
    required this.done,
    required this.onToggle,
  });

  final List<String> steps;
  final Set<int> done;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schritte ${done.length}/${steps.length}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          for (final (i, step) in steps.indexed)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: done.contains(i),
              onChanged: (_) => onToggle(i),
              title: Text(step),
            ),
        ],
      ),
    );
  }
}

/// Antippbarer Tag der Wochenleiste (nur ab Start der Challenge).
class _Dot extends StatelessWidget {
  const _Dot({
    super.key,
    required this.day,
    required this.firstDay,
    required this.onTap,
    required this.child,
  });

  final DateTime day;
  final DateTime firstDay;
  final ValueChanged<DateTime> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = !day.isBefore(firstDay);
    return Semantics(
      button: enabled,
      label: formatWeekdayDate(day),
      child: InkResponse(
        radius: 22,
        onTap: enabled ? () => onTap(day) : null,
        child: Padding(padding: const EdgeInsets.all(4), child: child),
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

/// Auswahl im Nachtrage-Sheet (null bedeutet „abgebrochen“).
enum _DayChoice { done, missed, empty }

enum _WindowState { idle, running, ended }

/// Baut [builder] alle 30 Sekunden neu mit der aktuellen Zeit, solange
/// [active] ist (z. B. für laufende Countdowns).
class _Ticker extends StatefulWidget {
  const _Ticker({
    required this.active,
    required this.clock,
    required this.builder,
  });

  final bool active;
  final Clock clock;
  final Widget Function(DateTime now) builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Ticker old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && _timer == null) {
      _timer = Timer.periodic(
          const Duration(seconds: 30), (_) => setState(() {}));
    } else if (!widget.active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.clock());
}
