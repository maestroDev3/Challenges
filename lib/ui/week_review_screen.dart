import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/week_review.dart';
import '../l10n/template_text.dart';
import 'detail_screen.dart';
import 'format.dart';
import 'l10n.dart';
import 'theme.dart';

/// Rückblick auf eine Kalenderwoche: Kennzahlen, je Challenge eine Karte
/// mit 7-Tage-Leiste, Abzeichen der Woche. Wird sonntags aus der
/// Benachrichtigung und aus dem Profil geöffnet.
class WeekReviewScreen extends StatelessWidget {
  const WeekReviewScreen({
    super.key,
    required this.repository,
    required this.weekStart,
    this.clock = DateTime.now,
  });

  final ChallengeRepository repository;

  /// Ein beliebiger Tag der Woche; gezeigt wird Mo–So.
  final DateTime weekStart;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<ChallengeStore>(
        stream: repository.watchStore(),
        builder: (context, snapshot) {
          final store = snapshot.data;
          if (store == null) return const SizedBox.shrink();
          final review = WeekReview.of(
            [...store.active, ...store.archived],
            weekStart: weekStart,
            today: clock(),
          );
          return _Body(review: review, clock: clock);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.review, required this.clock});

  final WeekReview review;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rate = review.rate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text(
          formatWeekdayDate(l10n, review.until),
          textAlign: TextAlign.center,
          style: text.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.weekReviewTitle,
          textAlign: TextAlign.center,
          style: text.headlineLarge,
        ),
        Text(
          'Sacrifice the moment. Evolve the future.',
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(
            fontFamily: ritualSerif,
            fontStyle: FontStyle.italic,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 28),
        if (review.entries.isEmpty)
          Text(
            l10n.weekReviewEmpty,
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Figure(
                value: l10n.weekReviewRatio(review.done, review.due),
                label: l10n.weekReviewDoneLabel,
                highlight: true,
              ),
              const _Divider(),
              _Figure(
                value: rate == null ? '–' : '${(rate * 100).round()} %',
                label: l10n.weekReviewRateLabel,
              ),
              if (review.totalMinutes > 0) ...[
                const _Divider(),
                _Figure(
                  value: formatMinutes(l10n, review.totalMinutes),
                  label: l10n.weekReviewMinutesLabel,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, e) in review.entries.indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _EntryRow(entry: e, index: i, clock: clock),
                  ],
                  const SizedBox(height: 10),
                  const _WeekdayLabels(),
                ],
              ),
            ),
          ),
          if (review.bestStreak > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.weekReviewBestStreak(review.bestStreak),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final b in review.badges) ...[
            const SizedBox(height: 12),
            _BadgeBanner(
              text: l10n.weekReviewBadge(
                l10n.daysCount(b.milestone),
                b.challenge.template.titleIn(l10n),
              ),
            ),
          ],
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.weekReviewClose),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: text.headlineMedium?.copyWith(
            color: highlight ? scheme.primary : scheme.onSurface,
          ),
        ),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}

/// Eine Challenge: Titel, „x von y“, Hinweise, 7-Tage-Leiste.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.index,
    required this.clock,
  });

  final WeekReviewEntry entry;
  final int index;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final notes = [
      if (entry.jokerDays > 0) l10n.weekReviewJokers(entry.jokerDays),
      if (entry.weeklyGoalReached case final reached?)
        reached ? l10n.weekReviewGoalReached : l10n.weekReviewGoalMissed,
    ];
    final c = entry.challenge;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChallengeDetailScreen(challenge: c, clock: clock),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  c.template.titleIn(l10n),
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.weekReviewRatio(entry.doneDays, entry.dueDays),
                style: text.titleMedium?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          if (notes.isNotEmpty)
            Text(
              notes.join(' · '),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, d) in entry.days.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    label: '${weekdayShort(l10n, i + 1)} '
                        '${dayStatusLabel(l10n, d)}',
                    child: Container(
                      key: Key('review-$index-day-$i'),
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: switch (d) {
                          DayStatus.done => scheme.primary,
                          DayStatus.missed => scheme.errorContainer,
                          DayStatus.open => scheme.surfaceContainerHighest,
                          DayStatus.paused => scheme.tertiaryContainer,
                          DayStatus.joker => scheme.surfaceContainerHighest,
                        },
                        border: d == DayStatus.joker
                            ? Border.all(color: scheme.primary)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 1; i <= 7; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(
              child: Text(
                weekdayShort(l10n, i),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeBanner extends StatelessWidget {
  const _BadgeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.military_tech_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
