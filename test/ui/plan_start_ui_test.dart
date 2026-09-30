import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 9, 30, 20);
final inThreeDays = DateTime(2026, 10, 3);

Future<DateTime?> pickInThreeDays(BuildContext context,
        {required DateTime initial,
        required DateTime first,
        required DateTime last}) async =>
    inThreeDays;

Future<void> pumpCatalog(WidgetTester tester, FakeChallengeRepository repo,
        {Locale locale = const Locale('de')}) =>
    tester.pumpApp(
      CatalogScreen(repository: repo, clock: () => now, pickDate: pickInThreeDays),
      size: const Size(900, 3200),
      locale: locale,
    );

void main() {
  testWidgets('Start-Sheet: „Beginnt Heute“, nach Datumswahl wird geplant',
      (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await pumpCatalog(tester, repo);
    await tester.tap(find.text('Kalt duschen'));
    await tester.pumpAndSettle();
    expect(find.text('Beginnt'), findsOneWidget);
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Challenge starten'), findsOneWidget);

    await tester.tap(find.text('Beginnt'));
    await tester.pumpAndSettle();
    expect(find.text('03.10.2026'), findsOneWidget);
    await tester.tap(find.text('Challenge planen'));
    await tester.pumpAndSettle();

    expect(repo.items.single.startedOn, dayOf(inThreeDays));
    expect(repo.items.single.isUpcoming(now), isTrue);
  });

  testWidgets('ohne Datumswahl startet die Challenge heute', (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await pumpCatalog(tester, repo);
    await tester.tap(find.text('Kalt duschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenge starten'));
    await tester.pumpAndSettle();
    expect(repo.items.single.startedOn, dayOf(now));
  });

  testWidgets('einmalige Vorlage mit festem Datum: kein zusätzliches Startdatum',
      (tester) async {
    final own = ChallengeTemplate.custom(
      title: 'Marathon',
      kind: OneTimeKind(const Duration(hours: 24), date: DateTime(2026, 10, 12)),
    );
    final repo = FakeChallengeRepository(today: now, templates: [own]);
    await pumpCatalog(tester, repo);
    await tester.tap(find.text('Marathon'));
    await tester.pumpAndSettle();
    expect(find.text('Beginnt'), findsNothing);
  });

  testWidgets('Editor: Startdatum wählen plant die neue Challenge',
      (tester) async {
    final repo = FakeChallengeRepository(today: now);
    await tester.pumpApp(
      ChallengeEditorScreen(
          repository: repo, clock: () => now, pickDate: pickInThreeDays),
      size: const Size(900, 3200),
    );
    await tester.enterText(find.byType(TextField).first, 'Lesen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beginnt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern & planen'));
    await tester.pumpAndSettle();
    expect(repo.items.single.startedOn, dayOf(inThreeDays));
  });

  testWidgets('auf Englisch', (tester) async {
    await pumpCatalog(tester, FakeChallengeRepository(today: now),
        locale: const Locale('en'));
    await tester.tap(find.text('Cold showers'));
    await tester.pumpAndSettle();
    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Starts'));
    await tester.pumpAndSettle();
    expect(find.text('Plan challenge'), findsOneWidget);
  });
}
