import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:challenges/ui/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

/// Dienstag, 20.10.2026, abends.
final now = DateTime(2026, 10, 20, 20, 0);
DateTime d(int month, int day) => DateTime(2026, month, day);

Iterable<DateTime> range(DateTime from, DateTime to) sync* {
  for (var x = from; !x.isAfter(to); x = x.add(const Duration(days: 1))) {
    yield x;
  }
}

/// „Meditieren vor dem Schlafen“: 1.–16.10. erledigt, 17.–19.10.
/// verpasst.
ActiveChallenge meditate() {
  var c = ActiveChallenge(
    id: 'meditate-sleep',
    template: templateById('meditate-sleep')!,
    startedOn: d(10, 1),
    reminder: const ReminderTime(7, 0),
  );
  for (final x in range(d(10, 1), d(10, 16))) {
    c = c.checkIn(x, CheckInStatus.done);
  }
  for (final x in range(d(10, 17), d(10, 19))) {
    c = c.checkIn(x, CheckInStatus.missed);
  }
  return c;
}

/// „21 Tage ohne Zucker“: 1.–20.9. erledigt, dann geschafft archiviert.
ActiveChallenge sugar() {
  var c = ActiveChallenge(
    id: 'no-sugar',
    template: templateById('no-sugar')!,
    startedOn: d(9, 1),
    reminder: const ReminderTime(7, 0),
  );
  for (final x in range(d(9, 1), d(9, 20))) {
    c = c.checkIn(x, CheckInStatus.done);
  }
  return c.copyWith(status: ChallengeStatus.completed, finishedOn: d(9, 21));
}

Widget screen(FakeChallengeRepository repo) =>
    StatisticsScreen(repository: repo, clock: () => now);

FakeChallengeRepository sampleRepo() =>
    FakeChallengeRepository(initial: [meditate()], archived: [sugar()]);

void main() {
  testWidgets(
      'die Navigation hat vier Ziele und „Statistik“ öffnet den Tab',
      (tester) async {
    await tester.pumpApp(HomeShell(
      repository: sampleRepo(),
      settings: FakeSettingsRepository(const AppSettings(name: 'Mia')),
      clock: () => now,
    ));
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Entdecken'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Dein Oktober'), findsOneWidget);
  });

  testWidgets('die vier Kacheln zeigen die berechneten Werte', (tester) async {
    await tester.pumpApp(screen(sampleRepo()));
    expect(find.text('Tage erledigt'), findsOneWidget);
    expect(find.text('16'), findsWidgets);
    expect(find.text('Längste Serie'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('21 Tage ohne Zucker'), findsWidgets);
    expect(find.text('Quote'), findsOneWidget);
    expect(find.text('84 %'), findsWidgets);
    expect(find.text('16 von 19 fällig'), findsOneWidget);
    expect(find.text('Rituale'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('aktiv / geschafft'), findsOneWidget);
  });

  testWidgets('Umschalten auf „Jahr“ ändert Untertitel und Werte',
      (tester) async {
    await tester.pumpApp(screen(sampleRepo()));
    await tester.tap(find.text('Jahr'));
    await tester.pumpAndSettle();
    expect(find.text('Dein 2026'), findsOneWidget);
    expect(find.text('36'), findsOneWidget); // 16 + 20 Tage
  });

  testWidgets('„Pro Ritual“ listet laufende Challenges; Tippen öffnet Detail',
      (tester) async {
    await tester.pumpApp(screen(sampleRepo()));
    expect(find.text('Pro Ritual'), findsOneWidget);
    expect(find.text('Meditieren vor dem Schlafen'), findsWidgets);
    // Archivierte Challenge steht nicht in der Liste.
    final list = find.byKey(const Key('per-ritual'));
    expect(
      find.descendant(of: list, matching: find.text('21 Tage ohne Zucker')),
      findsNothing,
    );
    await tester.tap(find.descendant(
        of: list, matching: find.text('Meditieren vor dem Schlafen')));
    await tester.pumpAndSettle();
    expect(find.text('Beste Streak'), findsOneWidget);
  });

  testWidgets('Abzeichen stehen mit Challenge, der nächste gestrichelt',
      (tester) async {
    await tester.pumpApp(screen(sampleRepo()));
    expect(find.text('Abzeichen'), findsOneWidget);
    expect(find.text('7 Tage · Meditieren vor dem Schlafen'), findsOneWidget);
    expect(find.text('7 Tage · 21 Tage ohne Zucker'), findsOneWidget);
    expect(
      find.byKey(const Key('next-milestone-meditate-sleep')),
      findsOneWidget,
    );
    expect(find.text('21 Tage · Meditieren vor dem Schlafen'), findsOneWidget);
  });

  testWidgets('ohne Challenges zeigt der Tab einen Leerhinweis',
      (tester) async {
    await tester.pumpApp(screen(FakeChallengeRepository()));
    expect(find.textContaining('Noch keine Zahlen'), findsOneWidget);
    expect(find.text('Tage erledigt'), findsNothing);
  });

  testWidgets('Texte gibt es auf Englisch und Russisch', (tester) async {
    await tester.pumpApp(screen(sampleRepo()), locale: const Locale('en'));
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Days done'), findsOneWidget);
    await tester.pumpApp(screen(sampleRepo()), locale: const Locale('ru'));
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Дней выполнено'), findsOneWidget);
  });
}
