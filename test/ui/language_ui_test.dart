import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';

Future<void> pumpRitual(WidgetTester tester, FakeSettingsRepository settings) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChallengesApp(
    repository: FakeChallengeRepository(),
    settings: settings,
    showIntro: false,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Englisch: Navigationsleiste auf Englisch', (tester) async {
    await pumpRitual(tester, FakeSettingsRepository(const AppSettings(language: 'en')));
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Russisch: Navigationsleiste auf Russisch', (tester) async {
    await pumpRitual(tester, FakeSettingsRepository(const AppSettings(language: 'ru')));
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Профиль'), findsOneWidget);
  });

  testWidgets('Sprache in den Einstellungen wählen wechselt sofort',
      (tester) async {
    final settings = FakeSettingsRepository(const AppSettings(language: 'de'));
    await pumpRitual(tester, settings);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(settings.current.language, 'en');
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('„Systemsprache“ setzt die Wahl zurück', (tester) async {
    final settings = FakeSettingsRepository(const AppSettings(language: 'de'));
    await pumpRitual(tester, settings);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Systemsprache'));
    await tester.pumpAndSettle();
    expect(settings.current.language, isNull);
  });

  testWidgets('Deutsch, Englisch und Russisch sind unterstützt', (tester) async {
    await pumpRitual(tester, FakeSettingsRepository());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales.map((l) => l.languageCode),
        containsAll(['de', 'en', 'ru']));
  });
}
