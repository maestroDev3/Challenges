import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/detail_screen.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

// Freitag, 9. Oktober 2026
final today = DateTime(2026, 10, 9, 10);
final start = DateTime(2026, 10, 5);
DateTime day(int offset) => start.add(Duration(days: offset));

ActiveChallenge challenge() {
  var c = ActiveChallenge(
    id: 'wake-5am',
    template: templateById('wake-5am')!,
    startedOn: start,
    reminder: const ReminderTime(5, 0),
  );
  for (final d in [0, 1, 2]) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c.checkIn(day(3), CheckInStatus.missed);
}

void main() {
  testWidgets('zeigt Streak, beste Streak und Erfolgsquote', (tester) async {
    await tester.pumpApp(
        ChallengeDetailScreen(challenge: challenge(), clock: () => today));
    expect(find.text('Um 5 Uhr aufstehen'), findsOneWidget);
    expect(find.text('75 %'), findsOneWidget);
    expect(find.text('Erfolgsquote'), findsOneWidget);
    expect(find.text('Beste Streak'), findsOneWidget);
  });

  testWidgets('Kalender zeigt den Status jedes Tages', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpApp(
        ChallengeDetailScreen(challenge: challenge(), clock: () => today));
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Mo, 05.10.: erledigt'), findsOneWidget);
    expect(find.bySemanticsLabel('Do, 08.10.: verpasst'), findsOneWidget);
    expect(find.bySemanticsLabel('Fr, 09.10.: offen'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('Monate wechseln, aber nicht vor den Start oder nach heute',
      (tester) async {
    final c = ActiveChallenge(
      id: 'x',
      template: templateById('wake-5am')!,
      startedOn: DateTime(2026, 9, 20),
      reminder: const ReminderTime(5, 0),
    );
    await tester.pumpApp(ChallengeDetailScreen(challenge: c, clock: () => today));
    IconButton button(String tip) => tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)));
    expect(button('Nächster Monat').onPressed, isNull);
    await tester.tap(find.byTooltip('Voriger Monat'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(button('Voriger Monat').onPressed, isNull);
  });

  testWidgets('Journal-Einträge erscheinen neueste zuerst', (tester) async {
    var c = ActiveChallenge(
      id: 'j',
      template: templateById('excuse-journal')!,
      startedOn: start,
      reminder: const ReminderTime(21, 0),
    );
    c = c.checkIn(day(0), CheckInStatus.done, note: 'Müde');
    c = c.checkIn(day(2), CheckInStatus.done, note: 'Keine Zeit');
    await tester.pumpApp(ChallengeDetailScreen(challenge: c, clock: () => today));
    await tester.scrollUntilVisible(find.text('Müde'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.getTopLeft(find.text('Keine Zeit')).dy,
        lessThan(tester.getTopLeft(find.text('Müde')).dy));
  });

  testWidgets('erreichbar aus Heute und aus dem Archiv', (tester) async {
    final finished = challenge().finish(today);
    final repo = FakeChallengeRepository(
      initial: [
        ActiveChallenge(
          id: 'cold',
          template: templateById('cold-shower')!,
          startedOn: start,
          reminder: const ReminderTime(7, 0),
        ),
      ],
      archived: [finished],
      today: today,
    );
    await tester.pumpApp(HomeShell(repository: repo, clock: () => today));

    await tester.tap(find.text('Kalt duschen'));
    await tester.pumpAndSettle();
    expect(find.byType(ChallengeDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Um 5 Uhr aufstehen'));
    await tester.pumpAndSettle();
    expect(find.byType(ChallengeDetailScreen), findsOneWidget);
  });
}
