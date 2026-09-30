import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 9, 30, 20);

ActiveChallenge challenge(String templateId, {required DateTime start}) =>
    ActiveChallenge(
      id: templateId,
      template: templateById(templateId)!,
      startedOn: dayOf(start),
      reminder: const ReminderTime(7, 0),
    );

final running = challenge('cold-shower', start: DateTime(2026, 9, 28));
final plannedIn2 = challenge('wake-5am', start: DateTime(2026, 10, 2));
final plannedTomorrow = challenge('no-sugar', start: DateTime(2026, 10, 1));

Future<DateTime?> pickOct10(BuildContext context,
        {required DateTime initial,
        required DateTime first,
        required DateTime last}) async =>
    DateTime(2026, 10, 10);

Future<void> pumpToday(WidgetTester tester, FakeChallengeRepository repo,
        {FakeReminderScheduler? scheduler, Locale locale = const Locale('de')}) =>
    tester.pumpApp(
      TodayScreen(
        repository: repo,
        onDiscover: () {},
        clock: () => now,
        scheduler: scheduler,
        pickDate: pickOct10,
      ),
      locale: locale,
    );

void main() {
  testWidgets('geplante Challenges stehen unter „Geplant“ mit Starttag',
      (tester) async {
    await pumpToday(tester,
        FakeChallengeRepository(initial: [running, plannedIn2, plannedTomorrow], today: now));
    expect(find.text('Geplant'), findsOneWidget);
    expect(find.text('startet am 02.10. · in 2 Tagen'), findsOneWidget);
    expect(find.text('startet am 01.10. · morgen'), findsOneWidget);
    // Die geplante Karte steht unter der laufenden.
    expect(tester.getTopLeft(find.text('Um 5 Uhr aufstehen')).dy,
        greaterThan(tester.getTopLeft(find.text('Kalt duschen')).dy));
  });

  testWidgets('geplante Karten haben keine Erledigt-Knöpfe und keine Streak',
      (tester) async {
    await pumpToday(tester, FakeChallengeRepository(initial: [plannedIn2], today: now));
    expect(find.text('Erledigt'), findsNothing);
    expect(find.text('Nicht erledigt'), findsNothing);
    expect(find.textContaining('🔥'), findsNothing);
  });

  testWidgets('nur geplante: kein Leerzustand, sondern der Abschnitt',
      (tester) async {
    await pumpToday(tester, FakeChallengeRepository(initial: [plannedIn2], today: now));
    expect(find.text('Noch keine Challenge aktiv'), findsNothing);
    expect(find.text('Geplant'), findsOneWidget);
  });

  testWidgets('„Jetzt starten“ beginnt heute und plant Erinnerungen',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [plannedIn2], today: now);
    final scheduler = FakeReminderScheduler();
    await pumpToday(tester, repo, scheduler: scheduler);
    await tester.tap(find.byTooltip('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jetzt starten'));
    await tester.pumpAndSettle();
    expect(repo.items.single.startedOn, dayOf(now));
    expect(scheduler.scheduled, {'wake-5am'});
    expect(find.text('Geplant'), findsNothing);
  });

  testWidgets('„Startdatum ändern“ verschiebt den Start', (tester) async {
    final repo = FakeChallengeRepository(initial: [plannedIn2], today: now);
    final scheduler = FakeReminderScheduler();
    await pumpToday(tester, repo, scheduler: scheduler);
    await tester.tap(find.byTooltip('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Startdatum ändern'));
    await tester.pumpAndSettle();
    expect(repo.items.single.startedOn, dayOf(DateTime(2026, 10, 10)));
    expect(scheduler.scheduled, {'wake-5am'});
    expect(find.text('startet am 10.10. · in 10 Tagen'), findsOneWidget);
  });

  testWidgets('„Löschen“ fragt nach und entfernt die geplante Challenge',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [plannedIn2], today: now);
    await pumpToday(tester, repo);
    await tester.tap(find.byTooltip('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
  });

  testWidgets('auf Englisch und Russisch', (tester) async {
    await pumpToday(tester, FakeChallengeRepository(initial: [plannedIn2], today: now),
        locale: const Locale('en'));
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('starts on 02/10 · in 2 days'), findsOneWidget);
  });
}
