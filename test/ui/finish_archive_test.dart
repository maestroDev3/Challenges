import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 25, 9);
DateTime daysAgo(int n) => today.subtract(Duration(days: n));

ActiveChallenge running(String id, {Iterable<int> doneDaysAgo = const []}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: dayOf(daysAgo(20)),
    reminder: const ReminderTime(7, 0),
  );
  for (final n in doneDaysAgo) {
    c = c.checkIn(daysAgo(n), CheckInStatus.done);
  }
  return c;
}

Future<void> openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Mehr'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Abschließen entfernt die Karte und zeigt sie im Archiv',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('meditate-sleep', doneDaysAgo: [1, 2, 3])],
        today: today);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(
        HomeShell(repository: repo, clock: () => today, scheduler: scheduler));

    await openMenu(tester, 'Abschließen');
    expect(repo.items, isEmpty);
    expect(repo.archivedItems.single.status, ChallengeStatus.ended);
    expect(scheduler.cancelled, ['meditate-sleep']);
    expect(find.text('Meditieren vor dem Schlafen'), findsNothing);

    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Meditieren vor dem Schlafen'), findsOneWidget);
    expect(find.text('Beendet'), findsOneWidget);
  });

  testWidgets('letzter nötiger Check-in zeigt die Feier und archiviert',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('no-sugar', doneDaysAgo: List.generate(20, (i) => i + 1))],
        today: today);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(
        HomeShell(repository: repo, clock: () => today, scheduler: scheduler));

    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();

    expect(find.text('Geschafft! 🏆'), findsOneWidget);
    expect(find.textContaining('Beste Streak: 21'), findsOneWidget);
    expect(repo.archivedItems.single.status, ChallengeStatus.completed);
    expect(scheduler.cancelled, ['no-sugar']);
  });

  testWidgets('Löschen fragt nach Bestätigung und entfernt endgültig',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('cold-shower')], today: today);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(
        HomeShell(repository: repo, clock: () => today, scheduler: scheduler));

    await openMenu(tester, 'Löschen');
    expect(find.text('Challenge löschen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
    expect(repo.archivedItems, isEmpty);
    expect(scheduler.cancelled, ['cold-shower']);
  });

  testWidgets('Archiv zeigt Zeitraum und beste Streak, „Nochmal starten“',
      (tester) async {
    final finished = running('cold-shower', doneDaysAgo: [3, 4, 5, 8])
        .finish(daysAgo(2));
    final repo = FakeChallengeRepository(archived: [finished], today: today);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(
        HomeShell(repository: repo, clock: () => today, scheduler: scheduler));

    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Kalt duschen'), findsOneWidget);
    expect(find.text('05.10. – 23.10.'), findsOneWidget);
    expect(find.text('Beste Streak 3'), findsOneWidget);
    expect(find.text('4 Tage erledigt'), findsOneWidget);

    await tester.tap(find.text('Nochmal starten'));
    await tester.pumpAndSettle();
    expect(repo.items.single.template.id, 'cold-shower');
    expect(scheduler.scheduled, {repo.items.single.id});
  });

  testWidgets('leeres Archiv zeigt einen Hinweis', (tester) async {
    await tester.pumpApp(HomeShell(
        repository: FakeChallengeRepository(today: today),
        clock: () => today));
    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Noch nichts abgeschlossen'), findsOneWidget);
  });

  testWidgets('Archiv passt auf Handybreite (360 dp)', (tester) async {
    final finished = running('cold-shower', doneDaysAgo: [3, 4, 5, 8])
        .finish(daysAgo(2));
    await tester.pumpApp(
      HomeShell(
          repository: FakeChallengeRepository(archived: [finished], today: today),
          clock: () => today),
      size: const Size(360, 780),
    );
    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nochmal starten'), findsOneWidget);
  });

  testWidgets('Einzahl: „1 Tag erledigt“', (tester) async {
    final finished = running('silence-24h', doneDaysAgo: [3]).finish(daysAgo(3));
    await tester.pumpApp(HomeShell(
        repository: FakeChallengeRepository(archived: [finished], today: today),
        clock: () => today));
    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('1 Tag erledigt'), findsOneWidget);
  });

  group('Archiv-Menü', () {
    Future<void> openArchiveMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('Erledigt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('Löschen fragt nach und entfernt endgültig', (tester) async {
      final repo = FakeChallengeRepository(
          archived: [running('cold-shower').finish(daysAgo(1))], today: today);
      await tester.pumpApp(HomeShell(repository: repo, clock: () => today));
      await openArchiveMenu(tester, 'Löschen');
      expect(find.text('Challenge löschen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(repo.archivedItems, isEmpty);
      expect(find.text('Noch nichts abgeschlossen'), findsOneWidget);
    });

    testWidgets('Wieder aufnehmen holt die Challenge zurück', (tester) async {
      final repo = FakeChallengeRepository(archived: [
        running('cold-shower', doneDaysAgo: [2, 3]).finish(daysAgo(1))
      ], today: today);
      final scheduler = FakeReminderScheduler();
      await tester.pumpApp(HomeShell(
          repository: repo, clock: () => today, scheduler: scheduler));
      await openArchiveMenu(tester, 'Wieder aufnehmen');
      expect(repo.archivedItems, isEmpty);
      expect(repo.items.single.doneDays, 2);
      expect(scheduler.scheduled, {'cold-shower'});
    });

    testWidgets('Wieder aufnehmen bei laufender Vorlage zeigt Hinweis',
        (tester) async {
      final repo = FakeChallengeRepository(
        initial: [running('cold-shower').copyWith()],
        archived: [
          ActiveChallenge(
            id: 'old',
            template: templateById('cold-shower')!,
            startedOn: dayOf(daysAgo(40)),
            reminder: const ReminderTime(7, 0),
          ).finish(daysAgo(30)),
        ],
        today: today,
      );
      await tester.pumpApp(HomeShell(repository: repo, clock: () => today));
      await openArchiveMenu(tester, 'Wieder aufnehmen');
      expect(find.textContaining('läuft bereits'), findsOneWidget);
      expect(repo.archivedItems, hasLength(1));
    });
  });

  testWidgets('Abschließen lässt sich rückgängig machen', (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running('meditate-sleep', doneDaysAgo: [1])], today: today);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(
        HomeShell(repository: repo, clock: () => today, scheduler: scheduler));
    await openMenu(tester, 'Abschließen');
    expect(repo.items, isEmpty);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(repo.items.single.id, 'meditate-sleep');
    expect(repo.archivedItems, isEmpty);
    expect(scheduler.scheduled, {'meditate-sleep'});
  });
}
