import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/milestones.dart';
import '../domain/statistics.dart';
import '../domain/streak_warning.dart';
import '../l10n/template_text.dart';
import 'detail_screen.dart';
import 'l10n.dart';
import 'stats_charts.dart';
import 'theme.dart';

/// Tab „Statistik“: Kennzahlen über alle Rituale, Liste pro Ritual und
/// Abzeichen-Wand. Zeitraum Monat/Jahr gilt für Kacheln und Zeit-Summen.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
  });

  final ChallengeRepository repository;
  final Clock clock;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _period = ValueNotifier(StatsPeriod.month);

  @override
  void dispose() {
    _period.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<ChallengeStore>(
        stream: widget.repository.watchStore(),
        builder: (context, snapshot) {
          final store = snapshot.data;
          if (store == null) return const SizedBox.shrink();
          final all = [...store.active, ...store.archived];
          return ValueListenableBuilder<StatsPeriod>(
            valueListenable: _period,
            builder: (context, period, _) {
              final today = widget.clock();
              final stats = Statistics.of(all, today: today, period: period);
              return _Body(
                stats: stats,
                open: openStreaks(store.active, today),
                period: period,
                today: today,
                onPeriod: (p) => _period.value = p,
                clock: widget.clock,
              );
            },
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.stats,
    required this.open,
    required this.period,
    required this.today,
    required this.onPeriod,
    required this.clock,
  });

  final Statistics stats;

  /// Serien, die heute noch offen sind (Zeile oben, siehe #135).
  final List<StreakWarning> open;
  final StatsPeriod period;
  final DateTime today;
  final ValueChanged<StatsPeriod> onPeriod;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = stats.active == 0 &&
        stats.completed == 0 &&
        stats.daysDone == 0 &&
        stats.badges.isEmpty &&
        stats.longestStreak == 0;
    final subtitle = switch (period) {
      StatsPeriod.month =>
        l10n.statsSubtitleMonth(l10n.monthName('${today.month}')),
      StatsPeriod.year => l10n.statsSubtitleYear('${today.year}'),
    };
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(l10n.statsTitle),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: text.titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  SegmentedButton<StatsPeriod>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: StatsPeriod.month,
                        label: Text(l10n.statsPeriodMonth),
                      ),
                      ButtonSegment(
                        value: StatsPeriod.year,
                        label: Text(l10n.statsPeriodYear),
                      ),
                    ],
                    selected: {period},
                    onSelectionChanged: (s) => onPeriod(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final w in open) ...[
                _OpenStreakLine(warning: w, clock: clock),
                const SizedBox(height: 10),
              ],
              if (open.isNotEmpty) const SizedBox(height: 10),
              if (isEmpty)
                Text(l10n.statsEmpty, style: text.bodyLarge)
              else ...[
                _TileGrid(stats: stats),
                const SizedBox(height: 24),
                _SectionTitle(l10n.statsHeatmapTitle,
                    hint: l10n.statsHeatmapHint),
                const SizedBox(height: 10),
                HeatmapGrid(values: stats.heatmap, start: stats.heatmapStart),
                const SizedBox(height: 24),
                _SectionTitle(l10n.statsWeeksTitle, hint: l10n.statsWeeksHint),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: WeekRateBars(weeks: stats.weeks),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ChartCard(
                        title: l10n.statsWeekdaysTitle,
                        child: WeekdayBars(
                          weekdays: stats.weekdays,
                          best: stats.bestWeekday,
                          worst: stats.worstWeekday,
                        ),
                      ),
                    ),
                    if (stats.minutesByChallenge.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChartCard(
                          title: l10n.statsTimeTitle,
                          hint: l10n.statsTimeHint,
                          child: MinutesList(
                            items: stats.minutesByChallenge,
                            total: stats.totalMinutes,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle(l10n.statsPerRitual),
                const SizedBox(height: 8),
                _PerRitual(stats: stats, clock: clock),
                const SizedBox(height: 24),
                _SectionTitle(l10n.badgesTitle),
                const SizedBox(height: 8),
                _BadgeWall(stats: stats),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ruhige Zeile „‹Ritual›: heute noch offen“; Tippen öffnet das Detail.
class _OpenStreakLine extends StatelessWidget {
  const _OpenStreakLine({required this.warning, required this.clock});

  final StreakWarning warning;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final c = warning.challenge;
    final detail = switch ((warning.weeklyDone, warning.weeklyTarget)) {
      (final d?, final t?) => l10n.statsOpenWeekly(d, t),
      _ => l10n.statsOpenStreakSerie(warning.streak),
    };
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ChallengeDetailScreen(challenge: c, clock: clock),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_outlined,
                  size: 20, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.statsOpenStreak(c.template.titleIn(l10n)),
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(detail,
                  style: TextStyle(color: scheme.onTertiaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: text.titleLarge)),
        if (hint case final h?)
          Text(h,
              style:
                  text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Kleine Karte mit Überschrift für Wochentage und Zeit.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall),
            const SizedBox(height: 10),
            child,
            if (hint case final h?) ...[
              const SizedBox(height: 6),
              Text(h,
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vier Kacheln in zwei Reihen.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rate = stats.rate;
    final longestTitle =
        stats.longestStreakChallenge?.template.titleIn(l10n) ?? '';
    final tiles = [
      _Tile(
        label: l10n.statsDaysDone,
        value: '${stats.daysDone}',
        hint: l10n.statsDaysDoneHint,
        highlight: true,
      ),
      _Tile(
        label: l10n.statsLongestStreak,
        value: '${stats.longestStreak}',
        hint: longestTitle,
      ),
      _Tile(
        label: l10n.statsRate,
        value: rate == null ? '–' : '${(rate * 100).round()} %',
        hint: l10n.statsRateHint(stats.done, stats.due),
      ),
      _Tile(
        label: l10n.statsRituals,
        value: '${stats.active} / ${stats.completed}',
        hint: l10n.statsRitualsHint,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.hint,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: text.headlineMedium?.copyWith(
              color: highlight ? scheme.primary : scheme.onSurface,
            ),
          ),
          Text(
            hint,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Laufende Rituale mit Serie und Quote; Tippen öffnet die Detailansicht.
class _PerRitual extends StatelessWidget {
  const _PerRitual({required this.stats, required this.clock});

  final Statistics stats;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('per-ritual'),
      child: Column(
        children: [
          for (final (i, s) in stats.perChallenge.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(s.challenge.template.titleIn(l10n)),
              subtitle: Text(kindLabelIn(l10n, s.challenge.kind)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasStreak(s.challenge.kind)
                        ? '${s.currentStreak}'
                        : (s.progress ?? 0) >= 1
                            ? l10n.resultDone
                            : l10n.resultOpen,
                    style: text.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontFamily: ritualSerif,
                    ),
                  ),
                  Text(
                    switch (s.rate) {
                      final r? => '${(r * 100).round()} %',
                      null => '–',
                    },
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChallengeDetailScreen(
                    challenge: s.challenge,
                    clock: clock,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Erreichte Abzeichen als Chips; je laufendem Ritual der nächste
/// Meilenstein gestrichelt.
class _BadgeWall extends StatelessWidget {
  const _BadgeWall({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final earned = [
      for (final b in stats.badges)
        _BadgeChip(
          label: l10n.statsBadgeChip(
            l10n.daysCount(b.milestone),
            b.challenge.template.titleIn(l10n),
          ),
          earned: true,
        ),
    ];
    final next = <Widget>[];
    for (final s in stats.perChallenge) {
      final c = s.challenge;
      if (!hasStreak(c.kind) || c.kind is WeeklyGoalKind) continue;
      for (final m in milestones) {
        if (c.bestStreak < m) {
          next.add(_BadgeChip(
            key: Key('next-milestone-${c.id}'),
            label: l10n.statsBadgeChip(
                l10n.daysCount(m), c.template.titleIn(l10n)),
            earned: false,
          ));
          break;
        }
      }
    }
    if (earned.isEmpty && next.isEmpty) {
      return Text('–', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [...earned, ...next]);
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({super.key, required this.label, required this.earned});

  final String label;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: earned ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(20),
        border: earned ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (earned) ...[
            Icon(Icons.military_tech_outlined,
                size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: earned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
