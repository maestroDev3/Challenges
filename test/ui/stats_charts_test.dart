import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/statistics.dart';
import 'package:challenges/domain/week_review.dart';
import 'package:challenges/ui/stats_charts.dart';
import 'package:challenges/ui/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

/// Dienstag, 20.10.2026.
final today = DateTime(2026, 10, 20, 20, 0);
DateTime d(int month, int day) => DateTime(2026, month, day);

ActiveChallenge daily(Iterable<DateTime> done) {
  var c = ActiveChallenge(
    id: 'meditate-sleep',
    template: templateById('meditate-sleep')!,
    startedOn: d(10, 1),
    reminder: const ReminderTime(7, 0),
  );
  for (final x in done) {
    c = c.checkIn(x, CheckInStatus.done);
  }
  return c;
}

ActiveChallenge nature(Map<DateTime, int> minutes) {
  var c = ActiveChallenge(
    id: 'nature',
    template: templateById('nature-2h')!,
    startedOn: d(9, 1),
    reminder: const ReminderTime(18, 0),
  );
  for (final e in minutes.entries) {
    c = c.checkIn(e.key, CheckInStatus.done, minutes: e.value);
  }
  return c;
}

/// Handy-Breite, damit die Diagramme wirklich scrollen müssen.
const phone = Size(390, 2600);

void main() {
  group('isoWeekNumber', () {
    test('ISO-Kalenderwoche', () {
      expect(isoWeekNumber(DateTime(2026, 10, 5)), 41);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
      expect(isoWeekNumber(DateTime(2027, 1, 1)), 53);
    });
  });

  group('HeatmapGrid', () {
    testWidgets('eine Zelle je Tag, am Ende gescrollt, Stufen per Semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final start = DateTime.utc(2025, 10, 27); // 52 Wochen vor dem 20.10.
      final values = <double?>[
        for (var i = 0; i < 52 * 7 - 5; i++) null,
      ];
      values[values.length - 1] = 1.0; // heute: alles erledigt
      values[values.length - 2] = 0.5;
      await tester.pumpApp(
        Scaffold(body: HeatmapGrid(values: values, start: start)),
        size: phone,
      );
      expect(find.byKey(const Key('heat-cell-0')), findsOneWidget);
      expect(find.byKey(Key('heat-cell-${values.length - 1}')), findsOneWidget);
      // Rechts (heute) sichtbar, links (vor einem Jahr) weggescrollt.
      expect(find.byKey(Key('heat-cell-${values.length - 1}')).hitTestable(),
          findsOneWidget);
      expect(find.byKey(const Key('heat-cell-0')).hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('Di, 20.10.: 100 %'), findsOneWidget);
      expect(find.bySemanticsLabel('Mo, 19.10.: 50 %'), findsOneWidget);
      expect(find.bySemanticsLabel('So, 18.10.: –'), findsOneWidget);
      expect(find.text('weniger'), findsOneWidget);
      expect(find.text('mehr'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('WeekRateBars', () {
    testWidgets('ein Balken je Woche mit Prozent und KW, am Ende gescrollt',
        (tester) async {
      final c = daily([d(10, 5), d(10, 6), d(10, 7), d(10, 8), d(10, 9)]);
      final weeks = <WeekReview>[
        for (var w = DateTime.utc(2026, 7, 27);
            !w.isAfter(DateTime.utc(2026, 10, 19));
            w = w.add(const Duration(days: 7)))
          WeekReview.of([c], weekStart: w, today: today),
      ];
      await tester.pumpApp(
        Scaffold(body: WeekRateBars(weeks: weeks)),
        size: phone,
      );
      expect(find.byKey(const Key('week-bar-0')), findsOneWidget);
      expect(find.byKey(Key('week-bar-${weeks.length - 1}')).hitTestable(),
          findsOneWidget);
      expect(find.byKey(const Key('week-bar-0')).hitTestable(), findsNothing);
      // Woche 5.–11.10.: 5 von 7 = 71 %; Wochen ohne Fälliges: „–“.
      expect(find.text('71 %'), findsOneWidget);
      expect(find.text('W41'), findsOneWidget);
      expect(find.text('–'), findsWidgets);
    });
  });

  group('WeekdayBars', () {
    testWidgets('nennt besten und schwächsten Wochentag', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: WeekdayBars(
            weekdays: const [0.88, 0.95, 0.84, 0.9, 0.78, 0.7, 0.61],
            best: DateTime.tuesday,
            worst: DateTime.sunday,
          ),
        ),
        size: phone,
      );
      expect(
          find.text('Stärkster Tag: Di · schwächster: So'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('So'), findsOneWidget);
    });
  });

  group('MinutesList', () {
    testWidgets('formatiert 220 Minuten als „3 h 40“ und 55 als „55 min“',
        (tester) async {
      final n = nature({d(10, 2): 220});
      final sport = ActiveChallenge(
        id: 'sport',
        template: templateById('nature-2h')!,
        startedOn: d(10, 1),
        reminder: const ReminderTime(7, 0),
      );
      await tester.pumpApp(
        Scaffold(
          body: MinutesList(
            items: [
              MinutesStat(challenge: n, minutes: 220),
              MinutesStat(challenge: sport, minutes: 55),
            ],
            total: 275,
          ),
        ),
      );
      expect(find.text('3 h 40'), findsOneWidget);
      expect(find.text('55 min'), findsOneWidget);
      expect(find.text('Gesamt'), findsOneWidget);
      expect(find.text('4 h 35'), findsOneWidget);
    });
  });

  group('StatisticsScreen mit Diagrammen', () {
    testWidgets('zeigt Heatmap, Wochen und Wochentage; ohne Wochenziele '
        'keinen Abschnitt „Zeit“', (tester) async {
      final repo = FakeChallengeRepository(initial: [daily([d(10, 19)])]);
      await tester.pumpApp(
        StatisticsScreen(repository: repo, clock: () => today),
        size: phone,
      );
      expect(find.text('Letzte Wochen'), findsOneWidget);
      expect(find.text('Erfolgsquote pro Woche'), findsOneWidget);
      expect(find.text('Wochentage'), findsOneWidget);
      expect(find.text('Zeit'), findsNothing);
    });

    testWidgets('mit Wochenziel in Minuten gibt es den Abschnitt „Zeit“',
        (tester) async {
      final repo = FakeChallengeRepository(initial: [nature({d(10, 2): 90})]);
      await tester.pumpApp(
        StatisticsScreen(repository: repo, clock: () => today),
        size: phone,
      );
      expect(find.text('Zeit'), findsOneWidget);
      expect(find.text('1 h 30'), findsWidgets);
    });
  });
}
