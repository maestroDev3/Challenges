import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

Future<void> pumpCatalog(WidgetTester tester, FakeChallengeRepository repo) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: CatalogScreen(repository: repo),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zeigt alle 11 Challenges', (tester) async {
    await pumpCatalog(tester, FakeChallengeRepository());
    for (final t in challengeCatalog) {
      expect(find.text(t.title), findsOneWidget, reason: t.id);
    }
  });

  testWidgets('Tipp öffnet Sheet mit Beschreibung und Erinnerungszeit',
      (tester) async {
    await pumpCatalog(tester, FakeChallengeRepository());
    await tester.tap(find.text('Um 5 Uhr aufstehen'));
    await tester.pumpAndSettle();

    final t = templateById('wake-5am')!;
    expect(find.text(t.description), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Challenge starten'), findsOneWidget);
  });

  testWidgets('Challenge starten ruft start mit Uhrzeit auf und schließt Sheet',
      (tester) async {
    final repo = FakeChallengeRepository();
    await pumpCatalog(tester, repo);
    await tester.tap(find.text('Um 5 Uhr aufstehen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenge starten'));
    await tester.pumpAndSettle();

    expect(repo.items.single.template.id, 'wake-5am');
    expect(repo.items.single.reminder, const ReminderTime(5, 0));
    expect(find.text('Challenge starten'), findsNothing);
  });

  testWidgets('aktive Challenges sind als „läuft“ markiert', (tester) async {
    final repo = FakeChallengeRepository();
    await repo.start(templateById('cold-shower')!, const ReminderTime(7, 0));
    await pumpCatalog(tester, repo);
    expect(find.text('läuft'), findsOneWidget);
  });
}
