import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 7, 7);

final routine = ChallengeTemplate.custom(
  title: 'Morgenroutine',
  kind: const DailyKind(days: 30),
  steps: ['Wasser', 'Bett machen', 'Dehnen', 'Tag planen'],
);

void main() {
  testWidgets('Karte zeigt Schritte und Teilfortschritt', (tester) async {
    final repo = FakeChallengeRepository(initial: [
      ActiveChallenge(
        id: 'r',
        template: routine,
        startedOn: dayOf(today),
        reminder: const ReminderTime(6, 0),
      ),
    ]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => today, onDiscover: () {}));
    expect(find.text('Bett machen'), findsOneWidget);
    await tester.tap(find.text('Wasser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dehnen'));
    await tester.pumpAndSettle();
    expect(find.text('Schritte 2/4'), findsOneWidget);
    expect(repo.items.single.checkInOn(today), isNull);

    await tester.tap(find.text('Bett machen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tag planen'));
    await tester.pumpAndSettle();
    expect(repo.items.single.checkInOn(today)!.status, CheckInStatus.done);
  });

  testWidgets('Editor: Schritte hinzufügen, umsortieren, löschen',
      (tester) async {
    final repo = FakeChallengeRepository(today: today);
    await tester.pumpApp(
        ChallengeEditorScreen(repository: repo, clock: () => today));
    await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Routine');
    for (final step in ['Wasser', 'Dehnen', 'Lesen']) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Neuer Schritt'), step);
      await tester.tap(find.byTooltip('Schritt hinzufügen'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('„Lesen“ nach oben'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('„Wasser“ löschen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Speichern & starten'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Speichern & starten'));
    await tester.pumpAndSettle();
    expect(repo.templates.single.steps, ['Lesen', 'Dehnen']);
  });
}
