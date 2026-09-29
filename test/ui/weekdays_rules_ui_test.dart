import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

// Mittwoch, 7. Oktober 2026
final today = DateTime(2026, 10, 7, 12);

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('Editor', () {
    testWidgets('Wochentage wählen setzt „Mal pro Woche“', (tester) async {
      final repo = FakeChallengeRepository(today: today);
      await tester.pumpApp(
          ChallengeEditorScreen(repository: repo, clock: () => today));
      await tester.enterText(field('Titel'), 'Laufen');
      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();
      for (final d in ['Mo', 'Mi', 'Fr']) {
        await tester.tap(find.text(d));
        await tester.pumpAndSettle();
      }
      final times = tester.widget<TextField>(field('Mal pro Woche'));
      expect(times.controller!.text, '3');
      expect(times.enabled, isFalse);

      await tester.scrollUntilVisible(find.text('Speichern & starten'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Speichern & starten'));
      await tester.pumpAndSettle();
      final kind = repo.templates.single.kind as WeeklyGoalKind;
      expect(kind.weekdays, {1, 3, 5});
      expect(kind.target, 3);
    });

    testWidgets('nur passende Regeln; Wechsel setzt auf Locker', (tester) async {
      final repo = FakeChallengeRepository(today: today);
      await tester.pumpApp(
          ChallengeEditorScreen(repository: repo, clock: () => today));
      await tester.enterText(field('Titel'), 'Kein Zucker');
      expect(find.text('Locker'), findsOneWidget);
      expect(find.text('Hart'), findsNothing);

      await tester.tap(find.text('X Tage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fortlaufend'));
      await tester.pumpAndSettle();
      expect(find.text('Hart'), findsNothing);

      await tester.tap(find.text('Einmalig'));
      await tester.pumpAndSettle();
      expect(find.text('Regel bei Fehltagen'), findsNothing);
      expect(find.text('Locker'), findsNothing);

      await tester.tap(find.text('Fortlaufend'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Speichern & starten'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Speichern & starten'));
      await tester.pumpAndSettle();
      expect(repo.items.single.rule, StreakRule.relaxed);
    });
  });

  group('Start-Sheet', () {
    testWidgets('einmalig ohne Regel, fortlaufend ohne „Hart“', (tester) async {
      await tester.pumpApp(CatalogScreen(
          repository: FakeChallengeRepository(today: today)));
      await tester.scrollUntilVisible(find.text('24 h Diät'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('24 h Diät'));
      await tester.pumpAndSettle();
      expect(find.text('Locker'), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // Sheet schließen
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Meditieren vor dem Schlafen'), -300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Meditieren vor dem Schlafen'));
      await tester.pumpAndSettle();
      expect(find.text('Locker'), findsOneWidget);
      expect(find.text('Hart'), findsNothing);
    });
  });

  group('Karte', () {
    testWidgets('einmalige Challenge zeigt keine Streak', (tester) async {
      final repo = FakeChallengeRepository(initial: [
        ActiveChallenge(
          id: 'f',
          template: templateById('fasting-24h')!,
          startedOn: dayOf(today),
          reminder: const ReminderTime(9, 0),
        ),
      ]);
      await tester.pumpApp(TodayScreen(
          repository: repo, clock: () => today, onDiscover: () {}));
      expect(find.textContaining('🔥'), findsNothing);
    });

    testWidgets('Wochenleiste markiert geplante Tage', (tester) async {
      final semantics = tester.ensureSemantics();
      final repo = FakeChallengeRepository(initial: [
        ActiveChallenge(
          id: 'run',
          template: ChallengeTemplate.custom(
              title: 'Laufen',
              kind: const WeeklyGoalKind(3,
                  unit: WeeklyUnit.times, weekdays: {1, 3, 5})),
          startedOn: DateTime(2026, 9, 28),
          reminder: const ReminderTime(18, 0),
        ),
      ]);
      await tester.pumpApp(TodayScreen(
          repository: repo, clock: () => today, onDiscover: () {}));
      // letzte 7 Tage: Do 1.10. … Mi 7.10. → Fr, Mo, Mi geplant
      expect(find.bySemanticsLabel(RegExp('geplant')), findsNWidgets(3));
      semantics.dispose();
    });
  });
}
