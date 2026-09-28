// Rendert echte Screenshots der App (keine Tests im engeren Sinn).
// Ausführen: flutter test screenshots --update-goldens
// Fonts werden über Umgebungsvariablen geladen (siehe .github/workflows/screenshots.yml).
import 'dart:io';

import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fake_repository.dart';

final now = DateTime(2026, 9, 28, 19, 30);
DateTime ago(int d) => now.subtract(Duration(days: d));

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    if (f.isEmpty || !File(f).existsSync()) continue;
    loader.addFont(
        File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

ActiveChallenge _c(String id,
    {List<int> done = const [], List<int> missed = const [], int minutes = 0}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: dayOf(ago(20)),
    reminder: defaultReminderFor(id),
  );
  for (final d in done) {
    c = c.checkIn(ago(d), CheckInStatus.done,
        minutes: minutes > 0 ? minutes : null,
        note: id == 'excuse-journal' ? 'Zu spät ins Bett' : null);
  }
  for (final d in missed) {
    c = c.checkIn(ago(d), CheckInStatus.missed);
  }
  return c;
}

List<ActiveChallenge> _demo() => [
      _c('wake-5am', done: List.generate(12, (i) => i)),
      _c('cold-shower', done: [1, 2, 3, 4]),
      _c('excuse-journal', done: [0, 2, 3], missed: [1]),
      _c('nature-2h', done: [1], minutes: 75),
    ];

Future<void> _pump(WidgetTester tester, Brightness b,
    FakeChallengeRepository repo,
    {DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final base = buildTheme(b, variant: variant);
  // Im Test-Renderer gibt es keinen System-Font: Button-Stil explizit auf Roboto.
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: ['NotoColorEmoji']),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.copyWith(
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        )),
      ),
    ),
  );
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: DefaultTextStyle.merge(
      style: const TextStyle(fontFamilyFallback: ['NotoColorEmoji']),
      child: HomeShell(repository: repo, clock: () => now),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _shot(String name) => expectLater(
    find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));

void main() {
  setUpAll(() async {
    final env = Platform.environment;
    final roboto = env['ROBOTO_DIR'] ?? '';
    await _loadFont('Roboto', [
      for (final w in ['Regular', 'Medium', 'Bold'])
        '$roboto/Roboto-$w.ttf',
    ]);
    await _loadFont('NotoColorEmoji', [env['EMOJI_FONT'] ?? '']);
    await _loadFont('MaterialIcons', [env['ICON_FONT'] ?? '']);
  });

  for (final b in Brightness.values) {
    final suffix = b == Brightness.dark ? '_dark' : '';

    testWidgets('heute$suffix', (tester) async {
      await _pump(tester, b, FakeChallengeRepository(initial: _demo()));
      await _shot('1_heute$suffix');
    });

    testWidgets('entdecken$suffix', (tester) async {
      await _pump(tester, b, FakeChallengeRepository(initial: _demo()));
      await tester.tap(find.text('Entdecken').last);
      await tester.pumpAndSettle();
      await _shot('2_entdecken$suffix');
    });
  }

  for (final (name, v) in [
    ('fidelity', DynamicSchemeVariant.fidelity),
    ('vibrant', DynamicSchemeVariant.vibrant),
  ]) {
    testWidgets('variante_$name', (tester) async {
      await _pump(tester, Brightness.light,
          FakeChallengeRepository(initial: _demo()),
          variant: v);
      await _shot('6_variante_$name');
    });
  }

  testWidgets('start_sheet', (tester) async {
    await _pump(tester, Brightness.light, FakeChallengeRepository());
    await tester.tap(find.text('Entdecken').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('21 Tage ohne Zucker'));
    await tester.pumpAndSettle();
    await _shot('3_starten');
  });

  testWidgets('journal_dialog', (tester) async {
    await _pump(tester, Brightness.light,
        FakeChallengeRepository(initial: [_c('excuse-journal', done: [1, 2])]));
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wollte lieber zocken');
    await tester.pumpAndSettle();
    await _shot('4_journal');
  });

  testWidgets('leer', (tester) async {
    await _pump(tester, Brightness.light, FakeChallengeRepository());
    await _shot('5_leer');
  });
}
