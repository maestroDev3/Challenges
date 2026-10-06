import 'package:flutter/material.dart';

import '../domain/statistics.dart';
import '../domain/week_review.dart';
import '../l10n/template_text.dart';
import 'format.dart';
import 'l10n.dart';

/// Scrollt nach dem Aufbau ans rechte Ende (heute), ohne Animation.
class _ScrollToEnd extends StatefulWidget {
  const _ScrollToEnd({required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<_ScrollToEnd> createState() => _ScrollToEndState();
}

class _ScrollToEndState extends State<_ScrollToEnd> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// Farbe für einen Anteil 0..1 in vier Stufen; null = nichts fällig.
Color heatColor(ColorScheme scheme, double? value) => switch (value) {
      null => scheme.surfaceContainerLow,
      <= 0 => scheme.surfaceContainerHighest,
      <= 0.5 => scheme.primaryContainer,
      < 1 => scheme.primary.withValues(alpha: 0.6),
      _ => scheme.primary,
    };

/// Heatmap: eine Spalte je Woche, sieben Zeilen (Mo oben), seitlich
/// scrollbar und am rechten Ende (heute) geöffnet.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({super.key, required this.values, required this.start});

  /// Ein Wert je Tag ab [start] (Montag), ältester zuerst.
  final List<double?> values;
  final DateTime start;

  static const _cell = 20.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final weeks = (values.length + 6) ~/ 7;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Column(
                children: [
                  for (var i = 1; i <= 7; i++)
                    SizedBox(
                      height: _cell + _gap,
                      width: 24,
                      child: i.isOdd
                          ? Text(weekdayShort(l10n, i), style: labelStyle)
                          : null,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _ScrollToEnd(
                builder: (controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var w = 0; w < weeks; w++)
                        Padding(
                          padding: const EdgeInsets.only(right: _gap),
                          child: Column(
                            children: [
                              for (var r = 0; r < 7; r++)
                                _cellFor(context, w * 7 + r),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(l10n.statsLess, style: labelStyle),
            const SizedBox(width: 6),
            for (final v in const [0.0, 0.3, 0.8, 1.0]) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: heatColor(scheme, v),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
            const SizedBox(width: 2),
            Text(l10n.statsMore, style: labelStyle),
          ],
        ),
      ],
    );
  }

  Widget _cellFor(BuildContext context, int index) {
    if (index >= values.length) {
      return const SizedBox(width: _cell, height: _cell + _gap);
    }
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final day = start.add(Duration(days: index));
    final value = values[index];
    final percent = value == null ? '–' : '${(value * 100).round()} %';
    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: '${formatWeekdayDate(l10n, day)}: $percent',
        child: Container(
          key: Key('heat-cell-$index'),
          width: _cell,
          height: _cell,
          decoration: BoxDecoration(
            color: heatColor(scheme, value),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Ein Balken je Kalenderwoche mit Prozent darüber und „W41“ darunter.
class WeekRateBars extends StatelessWidget {
  const WeekRateBars({super.key, required this.weeks});

  final List<WeekReview> weeks;

  static const _barWidth = 36.0;
  static const _gap = 10.0;
  static const _height = 80.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return _ScrollToEnd(
      builder: (controller) => SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, w) in weeks.indexed)
              Padding(
                padding:
                    EdgeInsets.only(right: i < weeks.length - 1 ? _gap : 0),
                child: SizedBox(
                  width: _barWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        switch (w.rate) {
                          final r? => '${(r * 100).round()} %',
                          null => '–',
                        },
                        style: labelStyle,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        key: Key('week-bar-$i'),
                        width: _barWidth,
                        height: switch (w.rate) {
                          final r? => (_height * r).clamp(3.0, _height),
                          null => 3.0,
                        },
                        decoration: BoxDecoration(
                          color: heatColor(scheme, w.rate),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.statsWeekShort(isoWeekNumber(w.from)),
                        style: labelStyle,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sieben kleine Balken Mo–So plus Zeile „Stärkster Tag: … · schwächster:
/// …“.
class WeekdayBars extends StatelessWidget {
  const WeekdayBars({
    super.key,
    required this.weekdays,
    required this.best,
    required this.worst,
  });

  /// Quote je Wochentag, Index 0 = Montag; null ohne Fälliges.
  final List<double?> weekdays;
  final int? best;
  final int? worst;

  static const _height = 56.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: switch (weekdays[i]) {
                        final r? => (_height * r).clamp(3.0, _height),
                        null => 3.0,
                      },
                      decoration: BoxDecoration(
                        color: heatColor(scheme, weekdays[i]),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(weekdayShort(l10n, i + 1), style: labelStyle),
                  ],
                ),
              ),
            ],
          ],
        ),
        if ((best, worst) case (final b?, final w?)) ...[
          const SizedBox(height: 8),
          Text(
            l10n.statsWeekdaysBestWorst(
              weekdayShort(l10n, b),
              weekdayShort(l10n, w),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Zeilen je Challenge plus „Gesamt“, Format „3 h 40“.
class MinutesList extends StatelessWidget {
  const MinutesList({super.key, required this.items, required this.total});

  final List<MinutesStat> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        for (final m in items)
          _MinutesRow(
              label: m.challenge.template.titleIn(l10n), minutes: m.minutes),
        const Divider(height: 12),
        _MinutesRow(label: l10n.statsTotal, minutes: total, muted: true),
      ],
    );
  }
}

class _MinutesRow extends StatelessWidget {
  const _MinutesRow({
    required this.label,
    required this.minutes,
    this.muted = false,
  });

  final String label;
  final int minutes;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: muted ? TextStyle(color: scheme.onSurfaceVariant) : null,
            ),
          ),
          Text(
            formatMinutes(context.l10n, minutes),
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
