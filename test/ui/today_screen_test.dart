import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/ui/theme.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';

final today = DateTime(2026, 10, 7, 9);
DateTime daysAgo(int n) => today.subtract(Duration(days: n));

ActiveChallenge running(String templateId, {List<int> doneDaysAgo = const []}) {
  var c = ActiveChallenge(
    id: templateId,
    template: templateById(templateId)!,
    startedOn: dayOf(daysAgo(5)),
    reminder: const ReminderTime(7, 0),
  );
  for (final n in doneDaysAgo) {
    c = c.checkIn(daysAgo(n), CheckInStatus.done);
  }
  return c;
}

Future<void> pumpToday(WidgetTester tester, FakeChallengeRepository repo,
    {VoidCallback? onDiscover}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: TodayScreen(
      repository: repo,
      clock: () => today,
      onDiscover: onDiscover ?? () {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Leerzustand zeigt Button „Challenge finden“', (tester) async {
    var discovered = false;
    await pumpToday(tester, FakeChallengeRepository(),
        onDiscover: () => discovered = true);
    await tester.tap(find.text('Challenge finden'));
    expect(discovered, isTrue);
  });

  testWidgets('Karte zeigt Titel, Streak und Fortschritt', (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('wake-5am', doneDaysAgo: [1, 2])]);
    await pumpToday(tester, repo);
    expect(find.text('Um 5 Uhr aufstehen'), findsOneWidget);
    expect(find.text('🔥 2'), findsOneWidget);
    expect(find.text('2/30'), findsOneWidget);
  });

  testWidgets('Erledigt speichert done und erhöht die Streak', (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('wake-5am', doneDaysAgo: [1, 2])]);
    await pumpToday(tester, repo);
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();

    expect(repo.items.single.checkInOn(today)!.status, CheckInStatus.done);
    expect(find.text('🔥 3'), findsOneWidget);
    expect(find.text('Heute erledigt'), findsOneWidget);
  });

  testWidgets('Nicht erledigt speichert missed und bleibt änderbar',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('wake-5am', doneDaysAgo: [1, 2])]);
    await pumpToday(tester, repo);
    await tester.tap(find.text('Nicht erledigt'));
    await tester.pumpAndSettle();

    expect(repo.items.single.checkInOn(today)!.status, CheckInStatus.missed);
    expect(find.text('Heute nicht geschafft'), findsOneWidget);
    expect(find.text('🔥 0'), findsOneWidget);

    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    expect(repo.items.single.checkInOn(today)!.status, CheckInStatus.done);
  });

  testWidgets('Journal speichert eingegebenen Text', (tester) async {
    final repo =
        FakeChallengeRepository(initial: [running('excuse-journal')]);
    await pumpToday(tester, repo);
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keine Zeit gehabt');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final ci = repo.items.single.checkInOn(today)!;
    expect(ci.status, CheckInStatus.done);
    expect(ci.note, 'Keine Zeit gehabt');
  });

  testWidgets('Wochenziel speichert Minuten', (tester) async {
    final repo = FakeChallengeRepository(initial: [running('nature-2h')]);
    await pumpToday(tester, repo);
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(repo.items.single.checkInOn(today)!.minutes, 45);
    expect(find.text('45/120 min'), findsOneWidget);
  });

  testWidgets('Meilenstein 7 Tage wird gefeiert', (tester) async {
    final repo = FakeChallengeRepository(initial: [
      running('meditate-sleep', doneDaysAgo: [1, 2, 3, 4, 5, 6])
    ]);
    await pumpToday(tester, repo);
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Meilenstein erreicht'), findsOneWidget);
    expect(find.text('7 Tage am Stück'), findsOneWidget);
  });

  testWidgets('nach dem Abhaken wird die Erinnerung neu geplant (#72)',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('wake-5am', doneDaysAgo: [1])]);
    final scheduler = FakeReminderScheduler();
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TodayScreen(
          repository: repo,
          clock: () => today,
          onDiscover: () {},
          scheduler: scheduler),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    expect(scheduler.scheduleCalls, 1);
  });
}
