import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/milestones.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'l10n.dart';
import 'template_text.dart';
import 'theme.dart';

/// Rückblick auf eine Challenge: Kennzahlen, Monatskalender, Journal.
class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({
    super.key,
    required this.challenge,
    this.clock = DateTime.now,
  });

  final ActiveChallenge challenge;
  final Clock clock;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  /// Letzter ausgewerteter Tag: heute bzw. Abschlusstag im Archiv.
  late final DateTime _end =
      widget.challenge.finishedOn ?? dayOf(widget.clock());
  late DateTime _month = DateTime.utc(_end.year, _end.month);

  void _shiftMonth(int delta) => setState(
      () => _month = DateTime.utc(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rate = c.successRate(_end);
    final first = DateTime.utc(dayOf(c.startedOn).year, dayOf(c.startedOn).month);
    final last = DateTime.utc(_end.year, _end.month);
    final kind = c.kind;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              EmojiBadge(c.template.emoji, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.template.titleIn(context.l10n),
                        style: text.headlineSmall),
                    Text(
                      context.l10n.detailSince(
                          kindLabelIn(context.l10n, c.kind),
                          formatDate(context.l10n, c.startedOn,
                              withYear: true)),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (hasStreak(c.kind)) ...[
                _Stat(
                    label: context.l10n.statStreak,
                    value: '🔥 ${c.currentStreak(_end)}'),
                _Stat(
                    label: context.l10n.statBestStreak,
                    value: '${c.bestStreak}'),
              ] else
                _Stat(
                  label: context.l10n.statResult,
                  value: c.isCompleted
                      ? context.l10n.resultDone
                      : context.l10n.resultOpen,
                ),
              _Stat(
                label: context.l10n.statSuccessRate,
                value: rate == null ? '–' : '${(rate * 100).round()} %',
              ),
              if (c.rule == StreakRule.strict)
                _Stat(
                    label: context.l10n.statAttempt,
                    value: '${c.attempt(_end)}'),
              if (c.rule == StreakRule.joker)
                _Stat(
                    label: context.l10n.joker, value: '🛡️ ${c.jokers(_end)}'),
            ],
          ),
          if (badges(c).isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(context.l10n.badgesTitle, style: text.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in badges(c))
                  Chip(
                    avatar: const Text('🏅'),
                    label: Text(context.l10n.daysCount(m)),
                  ),
              ],
            ),
          ],
          if (kind is WeeklyGoalKind) ...[
            const SizedBox(height: 16),
            Text(
              kind.unit == WeeklyUnit.times
                  ? context.l10n
                      .thisWeekTimes(c.doneDaysInWeek(_end), kind.target)
                  : context.l10n
                      .thisWeekMinutes(c.minutesInWeek(_end), kind.target),
              style: text.titleSmall,
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              IconButton(
                tooltip: context.l10n.previousMonth,
                onPressed: _month.isAfter(first) ? () => _shiftMonth(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  formatMonth(context.l10n, _month),
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
              ),
              IconButton(
                tooltip: context.l10n.nextMonth,
                onPressed: _month.isBefore(last) ? () => _shiftMonth(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 200 && _month.isAfter(first)) _shiftMonth(-1);
              if (v < -200 && _month.isBefore(last)) _shiftMonth(1);
            },
            child: _MonthGrid(month: _month, challenge: c, end: _end),
          ),
          const SizedBox(height: 12),
          const _Legend(),
          if (c.journalEntries.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(context.l10n.journalEntries, style: text.titleLarge),
            const SizedBox(height: 8),
            for (final e in c.journalEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(formatDate(context.l10n, e.day),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                title: Text(e.note ?? ''),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.titleLarge?.copyWith(color: scheme.primary)),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Label des Tagesstatus für Screenreader und Legende.
String dayStatusLabel(AppLocalizations l10n, DayStatus s) => switch (s) {
      DayStatus.done => l10n.statusDone,
      DayStatus.missed => l10n.statusMissed,
      DayStatus.open => l10n.statusOpen,
      DayStatus.paused => l10n.statusPaused,
      DayStatus.joker => l10n.joker,
    };

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.challenge,
    required this.end,
  });

  final DateTime month;
  final ActiveChallenge challenge;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = dayOf(challenge.startedOn);
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final leading = month.weekday - 1;
    final cells = <Widget>[
      for (var w = 1; w <= 7; w++)
        Center(
          child: Text(weekdayShort(context.l10n, w),
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ),
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: DateTime.utc(month.year, month.month, d),
          status: _statusFor(DateTime.utc(month.year, month.month, d), start),
          isToday: DateTime.utc(month.year, month.month, d) == end,
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }

  DayStatus? _statusFor(DateTime day, DateTime start) {
    if (day.isBefore(start) || day.isAfter(end)) return null;
    return challenge.statusOn(day, today: end);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.status, required this.isToday});

  final DateTime day;
  final DayStatus? status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      DayStatus.done => (scheme.primary, scheme.onPrimary),
      DayStatus.missed => (scheme.errorContainer, scheme.onErrorContainer),
      DayStatus.paused => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      DayStatus.joker => (scheme.secondaryContainer, scheme.primary),
      DayStatus.open => (scheme.surfaceContainerHigh, scheme.onSurface),
      null => (Colors.transparent, scheme.onSurfaceVariant.withValues(alpha: 0.5)),
    };
    final label = switch (status) {
      final s? =>
        '${formatWeekdayDate(context.l10n, day)}: ${dayStatusLabel(context.l10n, s)}',
      null => formatWeekdayDate(context.l10n, day),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Text('${day.day}',
            style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(scheme.primary, context.l10n.statusDone),
        item(scheme.errorContainer, context.l10n.statusMissed),
        item(scheme.secondaryContainer, context.l10n.joker),
        item(scheme.tertiaryContainer, context.l10n.statusPaused),
      ],
    );
  }
}
