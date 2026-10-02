import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/milestones.dart';
import '../domain/reminders.dart';
import '../l10n/template_text.dart';
import 'adjust_sheet.dart';
import 'archive_screen.dart';
import 'detail_screen.dart';
import 'format.dart';
import 'l10n.dart';
import 'plan_line.dart';
import 'theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.repository,
    required this.onDiscover,
    this.clock = DateTime.now,
    this.scheduler,
    this.pickTime = pickTimeDefault,
    this.pickDate = pickDateDefault,
  });

  final ChallengeRepository repository;
  final VoidCallback onDiscover;
  final Clock clock;
  final ReminderScheduler? scheduler;
  final TimePick pickTime;

  /// Datumsauswahl für „Startdatum ändern“ (im Test ersetzbar).
  final DatePick pickDate;

  /// Neuer Starttag für eine geplante Challenge.
  Future<void> _changeStart(BuildContext context, ActiveChallenge c) async {
    final today = dayOf(clock());
    final picked = await pickDate(
      context,
      initial: dayOf(c.startedOn),
      first: today,
      last: today.add(const Duration(days: maxPlanDays)),
    );
    if (picked == null) return;
    await _reschedule(c.withStart(picked, today: clock()));
  }

  Future<void> _adjust(BuildContext context, ActiveChallenge c) async {
    final updated = await showAdjustSheet(
      context,
      challenge: c,
      repository: repository,
      clock: clock,
      pickTime: pickTime,
    );
    if (updated != null) await _reschedule(updated);
  }

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
    // Termine neu berechnen (z. B. Wochenziel erreicht, Tag nachgetragen).
    await scheduler?.schedule(c);
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

  Future<void> _startSession(ActiveChallenge c) async {
    await repository.save(c);
    await scheduler?.showSession(c);
  }

  Future<void> _stopSession(BuildContext context, ActiveChallenge c) async {
    final saved = _save(context, c.stopSession(clock()));
    await scheduler?.clearSession(c);
    await saved;
  }

  Future<void> _finish(BuildContext context, ActiveChallenge c) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await repository.finish(c.id);
    await scheduler?.cancel(c);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.todayFinishedSnack(c.template.titleIn(l10n))),
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () async {
          final reopened = await repository.reopen(c.id);
          await scheduler?.schedule(reopened);
        },
      ),
    ));
  }

  Future<void> _delete(BuildContext context, ActiveChallenge c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteChallengeTitle),
        content: Text(context.l10n
            .todayDeleteMessage(c.template.titleIn(context.l10n))),
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
          final now = clock();
          final running = [
            for (final c in items)
              if (!c.isUpcoming(now)) c,
          ];
          final planned = [
            for (final c in items)
              if (c.isUpcoming(now)) c,
          ]..sort((a, b) => a.startedOn.compareTo(b.startedOn));
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(context.l10n.navToday),
                actions: [
                  IconButton(
                    tooltip: context.l10n.todayArchiveTooltip,
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
                  itemCount: running.length,
                  itemBuilder: (context, i) => _Ticker(
                    // Nur laufende Countdowns brauchen eine Live-Anzeige.
                    active: running[i].windowStartedAt != null ||
                        running[i].sessionStartedAt != null,
                    interval: running[i].sessionStartedAt != null
                        ? const Duration(seconds: 1)
                        : const Duration(seconds: 30),
                    clock: clock,
                    builder: (now) => ChallengeCard(
                      challenge: running[i],
                      today: now,
                      onSave: (c) => _save(context, c),
                      onFinish: (c) => _finish(context, c),
                      onDelete: (c) => _delete(context, c),
                      onPauseChanged: _reschedule,
                      onAdjust: (c) => _adjust(context, c),
                      onStartSession: _startSession,
                      onStopSession: (c) => _stopSession(context, c),
                    ),
                  ),
                ),
              if (planned.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text(
                      context.l10n.sectionPlanned,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: planned.length,
                  itemBuilder: (context, i) => _PlannedCard(
                    challenge: planned[i],
                    today: now,
                    onStartNow: () => _reschedule(planned[i].startNow(clock())),
                    onChangeStart: () => _changeStart(context, planned[i]),
                    onDelete: () => _delete(context, planned[i]),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

/// Karte einer geplanten Challenge: nur Starttag und Menü – noch keine
/// Check-ins, keine Streak.
class _PlannedCard extends StatelessWidget {
  const _PlannedCard({
    required this.challenge,
    required this.today,
    required this.onStartNow,
    required this.onChangeStart,
    required this.onDelete,
  });

  final ActiveChallenge challenge;
  final DateTime today;
  final VoidCallback onStartNow;
  final VoidCallback onChangeStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Card(
      color: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            EmojiBadge(challenge.template.emoji),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(challenge.template.titleIn(l10n),
                      style: text.titleMedium),
                  if (challenge.plan case final plan?) ...[
                    const SizedBox(height: 2),
                    PlanLine(plan),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    l10n.plannedStartsOn(
                      formatDate(l10n, challenge.startedOn),
                      switch (challenge.daysUntilStart(today)) {
                        1 => l10n.startsTomorrow,
                        final days => l10n.startsIn(days),
                      },
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.commonMore,
              onSelected: (action) => switch (action) {
                'start' => onStartNow(),
                'change' => onChangeStart(),
                _ => onDelete(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'start',
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow_rounded),
                    title: Text(l10n.startNow),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'change',
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(l10n.changeStartDate),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.commonDelete),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
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
          Text(context.l10n.todayEmptyTitle, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(
            context.l10n.todayEmptyBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDiscover,
            child: Text(context.l10n.todayFindChallenge),
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
    required this.onAdjust,
    required this.onStartSession,
    required this.onStopSession,
  });

  final ActiveChallenge challenge;
  final DateTime today;
  final Future<void> Function(ActiveChallenge) onSave;
  final Future<void> Function(ActiveChallenge) onFinish;
  final Future<void> Function(ActiveChallenge) onDelete;

  /// Challenge wurde pausiert oder fortgesetzt.
  final Future<void> Function(ActiveChallenge) onPauseChanged;

  /// Einstellungen der laufenden Challenge ändern (Erinnerung, Regel …).
  final Future<void> Function(ActiveChallenge) onAdjust;

  /// Aktivitäts-Timer starten (neuer Stand) bzw. stoppen (bisheriger Stand).
  final Future<void> Function(ActiveChallenge) onStartSession;
  final Future<void> Function(ActiveChallenge) onStopSession;

  Future<void> _pause(BuildContext context) async {
    final t = dayOf(today);
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.l10n.pauseTitle),
              subtitle: Text(context.l10n.pauseExplanation),
            ),
            for (final (days, label) in [
              (1, context.l10n.pauseToday),
              (3, context.l10n.daysCount(3)),
              (7, context.l10n.pauseWeek),
            ])
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: Text(label),
                onTap: () => Navigator.pop(context, days),
              ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(context.l10n.pauseUntilDate),
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
              title: Text(formatWeekdayDate(context.l10n, day)),
              subtitle: Text(context.l10n.correctSubtitle),
            ),
            ListTile(
              leading: const Icon(Icons.check_rounded),
              title: Text(context.l10n.commonDone),
              onTap: () => Navigator.pop(context, _DayChoice.done),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: Text(context.l10n.commonNotDone),
              onTap: () => Navigator.pop(context, _DayChoice.missed),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: Text(context.l10n.correctEmpty),
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
              title: context.l10n.askMinutes,
              hint: context.l10n.minutesHint,
              number: true) ??
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
            title: context.l10n.journalPrompt, hint: context.l10n.journalHint);
        if (note == null || note.trim().isEmpty) return;
        await onSave(
            challenge.checkIn(today, CheckInStatus.done, note: note.trim()));
      case WeeklyGoalKind(unit: WeeklyUnit.minutes):
        final raw = await _ask(context,
            title: context.l10n.askMinutesOutside,
            hint: context.l10n.minutesHint,
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
                      Text(challenge.template.titleIn(context.l10n),
                          style: text.titleMedium),
                      if (challenge.plan case final plan?) ...[
                        const SizedBox(height: 2),
                        PlanLine(plan),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (hasStreak(challenge.kind))
                          Text(
                            '🔥 ${challenge.currentStreak(today)}',
                            style: text.titleSmall,
                          ),
                          if (_progressLabel(context) case final label?)
                            Text(label,
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                          if (jokers != null)
                            Tooltip(
                              message: context.l10n.joker,
                              child: Text('🛡️ $jokers', style: text.titleSmall),
                            ),
                          if (attempt > 1)
                            Text(context.l10n.attempt(attempt),
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.commonMore,
                  onSelected: (action) => switch (action) {
                    'adjust' => onAdjust(challenge),
                    'pause' => _pause(context),
                    'finish' => onFinish(challenge),
                    _ => onDelete(challenge),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'adjust',
                      child: ListTile(
                        leading: const Icon(Icons.tune),
                        title: Text(context.l10n.menuAdjust),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!paused)
                      PopupMenuItem(
                        value: 'pause',
                        child: ListTile(
                          leading: const Icon(Icons.pause_circle_outline),
                          title: Text(context.l10n.pauseTitle),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'finish',
                      child: ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(context.l10n.menuFinish),
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
            ),
            const SizedBox(height: 12),
            _WeekRow(
              days: challenge.week(today),
              today: dayOf(today),
              firstDay: dayOf(challenge.startedOn),
              planned: switch (challenge.kind) {
                WeeklyGoalKind(weekdays: final w) => w,
                _ => const {},
              },
              onTapDay: (day) => _correct(context, day),
            ),
            if (challenge.template.steps.isNotEmpty && !paused)
              _Checklist(
                steps: challenge.template.stepsIn(context.l10n),
                done: challenge.stepsDoneOn(today),
                onToggle: (i) => onSave(challenge.toggleStep(today, i)),
              ),
            const SizedBox(height: 12),
            if (challenge.isCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(context.l10n.completedBanner,
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
                        context.l10n
                            .pausedUntil(formatDate(context.l10n, pausedUntil)),
                        style: text.titleSmall,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => onPauseChanged(challenge.resume(today)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(context.l10n.resume),
                    ),
                  ],
                ),
              ),
            if (!paused && window == null && challenge.template.isTimed)
              _SessionRow(
                target: challenge.template.targetDuration,
                elapsed: challenge.sessionElapsed(today),
                onStart: () => onStartSession(challenge.startSession(today)),
                onStop: () => onStopSession(challenge),
              ),
            if (!paused && window == _WindowState.idle)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () =>
                      onPauseChanged(challenge.startWindow(today)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(context.l10n.startNow),
                ),
              ),
            if (!paused && window == _WindowState.running)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.remainingTime(formatRemaining(
                            challenge.remaining(today) ?? Duration.zero)),
                        style: text.titleLarge?.copyWith(
                          color: scheme.primary,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onPauseChanged(challenge.cancelWindow()),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            if (!paused && window == _WindowState.ended)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(context.l10n.windowEndedQuestion,
                    textAlign: TextAlign.center, style: text.titleLarge),
              ),
            if (!paused && status != null && !isWeekly)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(
                  status == CheckInStatus.done
                      ? context.l10n.todayDoneStatus
                      : context.l10n.todayMissedStatus,
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
                      label: context.l10n.commonNotDone,
                      icon: Icons.close_rounded,
                      selected: status == CheckInStatus.missed,
                      onPressed: _missed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoiceButton(
                      label: context.l10n.commonDone,
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

  String? _progressLabel(BuildContext context) => switch (challenge.kind) {
        DailyKind(days: final d?) =>
          '${((challenge.progress(today) ?? 0) * d).round()}/$d',
        WeeklyGoalKind(unit: WeeklyUnit.times, target: final n) =>
          '${challenge.doneDaysInWeek(today)}/$n×',
        WeeklyGoalKind(target: final m) =>
          context.l10n.minutesProgress(challenge.minutesInWeek(today), m),
        OneTimeKind() => challenge.isCompleted || challenge.windowStartedAt != null
            ? null
            : context.l10n.oneTimeLabel,
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
    this.planned = const {},
  });

  final List<DayStatus> days;
  final DateTime today;
  final DateTime firstDay;
  final ValueChanged<DateTime> onTapDay;

  /// Geplante Wochentage (1 = Mo), z. B. bei „3×/Woche · Mo Mi Fr“.
  final Set<int> planned;

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
              planned: planned.contains(
                  today.subtract(Duration(days: days.length - 1 - i)).weekday),
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
                    : planned.contains(today
                                .subtract(Duration(days: days.length - 1 - i))
                                .weekday) &&
                            d == DayStatus.open
                        ? Border.all(
                            color: scheme.primary.withValues(alpha: 0.6))
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
          Text(context.l10n.stepsProgress(done.length, steps.length),
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
    this.planned = false,
  });

  final DateTime day;
  final DateTime firstDay;
  final bool planned;
  final ValueChanged<DateTime> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = !day.isBefore(firstDay);
    return Semantics(
      button: enabled,
      label: planned
          ? context.l10n.plannedDay(formatWeekdayDate(context.l10n, day))
          : formatWeekdayDate(context.l10n, day),
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
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.l10n.commonSave),
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
    this.interval = const Duration(seconds: 30),
  });

  final bool active;
  final Duration interval;
  final Clock clock;
  final Widget Function(DateTime now) builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  Timer? _timer;
  Duration? _interval;

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
    if (_timer != null && _interval != widget.interval) {
      _timer?.cancel();
      _timer = null;
    }
    if (widget.active && _timer == null) {
      _interval = widget.interval;
      _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
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

/// Aktivitäts-Timer auf der Karte: „Starten“ bzw. laufende Zeit und „Stopp“.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.target,
    required this.elapsed,
    required this.onStart,
    required this.onStop,
  });

  final Duration? target;
  final Duration? elapsed;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final running = elapsed;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: running == null
                ? Text(
                    switch (target) {
                      final t? => context.l10n.sessionTarget(t.inMinutes),
                      null => context.l10n.sessionFree,
                    },
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                : Text(
                    switch (target) {
                      final t? =>
                        '${formatStopwatch(running)} / ${formatStopwatch(t)}',
                      null => formatStopwatch(running),
                    },
                    style: text.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
          if (running == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: onStart,
              icon: const Icon(Icons.timer_outlined),
              label: Text(context.l10n.sessionStart),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              label: Text(context.l10n.sessionStop),
            ),
        ],
      ),
    );
  }
}
