import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 2, 20);

const whenField = Key('plan-when');
const whereField = Key('plan-where');

Future<void> openStartSheet(WidgetTester tester, FakeChallengeRepository repo,
    {Locale locale = const Locale('de'), String title = 'Kalt duschen'}) async {
  await tester.pumpApp(
    CatalogScreen(repository: repo, clock: () => now),
    size: const Size(900, 3200),
    locale: locale,
  );
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ActiveChallenge running({String? when, String? where}) => ActiveChallenge(
      id: 'cold-shower',
      template: templateById('cold-shower')!,
      startedOn: dayOf(DateTime(2026, 9, 28)),
      reminder: const ReminderTime(7, 0),
    ).withPlan(when: when, where: where);

Future<void> openAdjust(WidgetTester tester, FakeChallengeRepository repo) async {
  await tester.pumpApp(
    TodayScreen(repository: repo, clock: () => now, onDiscover: () {}),
    size: const Size(900, 3200),
  );
  await tester.tap(find.byTooltip('Mehr'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Anpassen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Start-Sheet: „Wann?“ und „Wo?“ ausgefüllt ergibt den Plan',
      (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await openStartSheet(tester, repo);
    expect(find.text('Wann?'), findsOneWidget);
    expect(find.text('Wo?'), findsOneWidget);
    await tester.enterText(find.byKey(whenField), 'Nach dem Aufstehen');
    await tester.enterText(find.byKey(whereField), 'im Bad');
    await tapVisible(tester, find.text('Challenge starten'));
    expect(repo.items.single.plan, 'Nach dem Aufstehen, im Bad');
  });

  testWidgets('Start-Sheet ohne Eingabe: Challenge ohne Plan', (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await openStartSheet(tester, repo);
    await tapVisible(tester, find.text('Challenge starten'));
    expect(repo.items.single.plan, isNull);
  });

  testWidgets('Vorschlag „Nach dem Aufstehen“ füllt „Wann?“', (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await openStartSheet(tester, repo);
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Nach dem Aufstehen'));
    expect(
        tester.widget<TextField>(find.byKey(whenField)).controller?.text,
        'Nach dem Aufstehen');
    await tapVisible(tester, find.text('Challenge starten'));
    expect(repo.items.single.planWhen, 'Nach dem Aufstehen');
  });

  testWidgets('Editor: Plan beim Anlegen wird gespeichert', (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await tester.pumpApp(
      ChallengeEditorScreen(repository: repo, clock: () => now),
      size: const Size(900, 3200),
    );
    await tester.enterText(find.byType(TextField).first, 'Lesen');
    await tester.enterText(find.byKey(whenField), 'Vor dem Schlafengehen');
    await tester.enterText(find.byKey(whereField), 'im Sessel');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Speichern & starten'));
    expect(repo.items.single.plan, 'Vor dem Schlafengehen, im Sessel');
  });

  testWidgets('Anpassen zeigt den Plan; Änderung wird gespeichert',
      (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running(when: 'Nach dem Aufstehen', where: 'im Bad')],
        today: now);
    await openAdjust(tester, repo);
    expect(tester.widget<TextField>(find.byKey(whenField)).controller?.text,
        'Nach dem Aufstehen');
    await tester.enterText(find.byKey(whereField), 'im Fitnessstudio');
    await tapVisible(tester, find.text('Speichern'));
    expect(repo.items.single.plan, 'Nach dem Aufstehen, im Fitnessstudio');
  });

  testWidgets('Anpassen: geleerte Felder entfernen den Plan', (tester) async {
    final repo = FakeChallengeRepository(
        initial: [running(when: 'Nach dem Aufstehen', where: 'im Bad')],
        today: now);
    await openAdjust(tester, repo);
    await tester.enterText(find.byKey(whenField), '');
    await tester.enterText(find.byKey(whereField), '');
    await tapVisible(tester, find.text('Speichern'));
    expect(repo.items.single.plan, isNull);
  });

  testWidgets('Felder und Vorschläge auf Englisch', (tester) async {
    await openStartSheet(tester, FakeChallengeRepository(today: now),
        locale: const Locale('en'), title: 'Cold showers');
    expect(find.text('When?'), findsOneWidget);
    expect(find.text('Where?'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'After waking up'), findsOneWidget);
  });

  testWidgets('Felder und Vorschläge auf Russisch', (tester) async {
    await openStartSheet(tester, FakeChallengeRepository(today: now),
        locale: const Locale('ru'), title: 'Холодный душ');
    expect(find.text('Когда?'), findsOneWidget);
    expect(find.text('Где?'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'После пробуждения'), findsOneWidget);
  });
}
