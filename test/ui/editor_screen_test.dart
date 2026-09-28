import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 5, 12);

Finder field(String label) => find.widgetWithText(TextField, label);

FilledButton button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void main() {
  group('Editor: neue Challenge', () {
    testWidgets('ohne Titel ist „Speichern & starten“ deaktiviert',
        (tester) async {
      await tester.pumpApp(ChallengeEditorScreen(
          repository: FakeChallengeRepository(), clock: () => today));
      expect(button(tester, 'Speichern & starten').onPressed, isNull);
      await tester.enterText(field('Titel'), 'Sport');
      await tester.pump();
      expect(button(tester, 'Speichern & starten').onPressed, isNotNull);
    });

    testWidgets('Art zeigt nur die passenden Felder', (tester) async {
      await tester.pumpApp(ChallengeEditorScreen(
          repository: FakeChallengeRepository(), clock: () => today));
      expect(field('Anzahl Tage'), findsNothing);
      expect(find.text('Datum'), findsNothing);

      await tester.tap(find.text('X Tage'));
      await tester.pumpAndSettle();
      expect(field('Anzahl Tage'), findsOneWidget);

      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();
      expect(field('Anzahl Tage'), findsNothing);
      expect(field('Mal pro Woche'), findsOneWidget);
      await tester.tap(find.text('Minuten'));
      await tester.pumpAndSettle();
      expect(field('Minuten pro Woche'), findsOneWidget);

      await tester.tap(find.text('Einmalig'));
      await tester.pumpAndSettle();
      expect(field('Minuten pro Woche'), findsNothing);
      expect(find.text('Datum'), findsOneWidget);
      expect(find.text('06.10.2026'), findsOneWidget); // Standard: morgen
    });

    testWidgets('Speichern legt Vorlage an und startet sie', (tester) async {
      final repo = FakeChallengeRepository(today: today);
      ActiveChallenge? started;
      await tester.pumpApp(ChallengeEditorScreen(
        repository: repo,
        clock: () => today,
        onStarted: (c) async => started = c,
      ));
      await tester.enterText(field('Titel'), 'Sport');
      await tester.tap(find.text('🏃'));
      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Mal pro Woche'), '3');
      await tester.pump();
      await tester.tap(find.text('Speichern & starten'));
      await tester.pumpAndSettle();

      final t = repo.templates.single;
      expect(t.title, 'Sport');
      expect(t.emoji, '🏃');
      expect(t.isCustom, isTrue);
      final kind = t.kind as WeeklyGoalKind;
      expect((kind.target, kind.unit), (3, WeeklyUnit.times));
      expect(repo.items.single.template.id, t.id);
      expect(repo.items.single.reminder, const ReminderTime(9, 0));
      expect(started?.template.id, t.id);
    });

    testWidgets('X Tage speichert die Anzahl', (tester) async {
      final repo = FakeChallengeRepository(today: today);
      await tester.pumpApp(ChallengeEditorScreen(
          repository: repo, clock: () => today));
      await tester.enterText(field('Titel'), 'Kein Alkohol');
      await tester.tap(find.text('X Tage'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Anzahl Tage'), '66');
      await tester.pump();
      await tester.tap(find.text('Speichern & starten'));
      await tester.pumpAndSettle();
      expect((repo.templates.single.kind as DailyKind).days, 66);
    });
  });

  group('Katalog: eigene Challenges', () {
    final sport = ChallengeTemplate.custom(
        title: 'Sport',
        emoji: '🏃',
        kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times));

    testWidgets('erscheinen unter „Meine Challenges“', (tester) async {
      await tester.pumpApp(CatalogScreen(
          repository: FakeChallengeRepository(templates: [sport])));
      expect(find.text('Meine Challenges'), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);
      expect(find.text('Eigene Challenge'), findsOneWidget);
    });

    testWidgets('Bearbeiten öffnet den Editor vorausgefüllt', (tester) async {
      final repo = FakeChallengeRepository(templates: [sport]);
      await tester.pumpApp(CatalogScreen(repository: repo));
      await tester.tap(find.text('Sport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Sport'), findsOneWidget);
      await tester.enterText(field('Titel'), 'Training');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(repo.templates.single.title, 'Training');
      expect(repo.templates.single.id, sport.id);
    });

    testWidgets('Löschen fragt nach Bestätigung', (tester) async {
      final repo = FakeChallengeRepository(templates: [sport]);
      await tester.pumpApp(CatalogScreen(repository: repo));
      await tester.tap(find.text('Sport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Vorlage löschen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(repo.templates, isEmpty);
    });
  });
}
