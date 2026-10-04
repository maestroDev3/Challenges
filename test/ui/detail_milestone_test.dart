import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Sonntag, 4. Oktober 2026: siebter Tag am Stück.
final today = DateTime(2026, 10, 4, 20);
final start = DateTime(2026, 9, 28);
DateTime day(int offset) => start.add(Duration(days: offset));

ActiveChallenge streakOf(String id, int days) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: start,
    reminder: const ReminderTime(5, 0),
  );
  for (var i = 0; i < days; i++) {
    c = c.checkIn(day(i), CheckInStatus.done);
  }
  return c;
}

void main() {
  testWidgets('nach 7 Tagen: „Nächster Meilenstein“ 21, noch 14 Tage, Datum',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpApp(ChallengeDetailScreen(
      challenge: streakOf('meditate-sleep', 7),
      clock: () => today,
    ));
    expect(find.text('Nächster Meilenstein'), findsOneWidget);
    expect(find.text('noch 14 Tage'), findsOneWidget);
    expect(find.textContaining('18.10.'), findsWidgets);
    expect(find.bySemanticsLabel('7: erreicht'), findsOneWidget);
    expect(find.bySemanticsLabel('21: nächster'), findsOneWidget);
    expect(find.bySemanticsLabel('30: offen'), findsOneWidget);
    expect(find.bySemanticsLabel('100: offen'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('der Kalender markiert den Tag des nächsten Meilensteins',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpApp(ChallengeDetailScreen(
      challenge: streakOf('meditate-sleep', 7),
      clock: () => today,
    ));
    expect(find.bySemanticsLabel('So, 18.10.: Meilenstein 21'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('bei einmaligen und Wochenziel-Challenges fehlt die Karte',
      (tester) async {
    await tester.pumpApp(ChallengeDetailScreen(
      challenge: streakOf('fasting-24h', 0),
      clock: () => today,
    ));
    expect(find.text('Nächster Meilenstein'), findsNothing);
    await tester.pumpApp(ChallengeDetailScreen(
      challenge: streakOf('nature-2h', 0),
      clock: () => today,
    ));
    expect(find.text('Nächster Meilenstein'), findsNothing);
  });

  testWidgets('Texte auf Englisch', (tester) async {
    await tester.pumpApp(
      ChallengeDetailScreen(
        challenge: streakOf('meditate-sleep', 7),
        clock: () => today,
      ),
      locale: const Locale('en'),
    );
    expect(find.text('Next milestone'), findsOneWidget);
    expect(find.text('14 days to go'), findsOneWidget);
  });
}
