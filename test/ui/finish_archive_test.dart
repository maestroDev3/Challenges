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
}
