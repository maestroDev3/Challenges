// Rendert echte Screenshots der App (keine Tests im engeren Sinn).
// Ausführen: flutter test screenshots --update-goldens
// Fonts werden über Umgebungsvariablen geladen (siehe .github/workflows/screenshots.yml).
import 'dart:io';

import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:challenges/ui/intro_screen.dart';
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
      _c('wake-5am', done: List.generate(12, (i) => i))
          .copyWith(rule: StreakRule.joker),
      _c('cold-shower', done: [1, 2, 3, 4]),
      _c('no-sugar', done: [1, 2, 3, 5, 6], missed: [4])
          .copyWith(rule: StreakRule.strict),
      _c('excuse-journal', done: [0, 2, 3], missed: [1]),
      _c('meditate-sleep', done: [3, 4, 5])
          .pause(from: ago(2), until: ago(-2)),
    ];

final _sport = ChallengeTemplate.custom(
  title: '3× pro Woche Sport',
  emoji: '🏃',
  description: 'Laufen, Gym oder Rad – Hauptsache bewegt.',
  kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times),
);

Future<void> _pump(WidgetTester tester, FakeChallengeRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final base = buildTheme();
  // Im Test-Renderer gibt es keinen System-Font: Roboto und Emoji explizit.
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

FakeChallengeRepository _repo() => FakeChallengeRepository(
      initial: _demo(),
      templates: [_sport],
      archived: [
        _c('silence-24h', done: [9]).finish(ago(9)),
        _c('eye-gaze', done: [15, 16, 17, 18]).finish(ago(14)),
      ],
      today: now,
    );

void main() {
  setUpAll(() async {
    final env = Platform.environment;
    final roboto = env['ROBOTO_DIR'] ?? '';
    await _loadFont('Roboto', [
      for (final w in ['Regular', 'Medium', 'Bold']) '$roboto/Roboto-$w.ttf',
    ]);
    await _loadFont('NotoColorEmoji', [env['EMOJI_FONT'] ?? '']);
    await _loadFont('MaterialIcons', [env['ICON_FONT'] ?? '']);
    await _loadFont(ritualSerif, [
      for (final f in ['Regular', 'Medium', 'SemiBold', 'Italic', 'MediumItalic'])
        'assets/fonts/CormorantGaramond-$f.ttf',
    ]);
  });

  testWidgets('heute', (tester) async {
    await _pump(tester, _repo());
    await _shot('1_heute');
  });

  testWidgets('entdecken', (tester) async {
    await _pump(tester, _repo());
    await tester.tap(find.text('Entdecken').last);
    await tester.pumpAndSettle();
    await _shot('2_entdecken');
  });

  testWidgets('starten', (tester) async {
    await _pump(tester, FakeChallengeRepository(today: now));
    await tester.tap(find.text('Entdecken').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('21 Tage ohne Zucker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joker'));
    await tester.pumpAndSettle();
    await _shot('3_starten');
  });

  testWidgets('editor', (tester) async {
    await _pump(tester, FakeChallengeRepository(today: now));
    await tester.tap(find.text('Entdecken').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eigene Challenge'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3× pro Woche Sport');
    await tester.tap(find.text('🏃'));
    await tester.tap(find.text('Wöchentlich'));
    await tester.pumpAndSettle();
    await _shot('4_editor');
  });

  testWidgets('archiv', (tester) async {
    await _pump(tester, _repo());
    await tester.tap(find.byTooltip('Erledigt'));
    await tester.pumpAndSettle();
    await _shot('5_archiv');
  });

  testWidgets('intro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(1080 / 2.625, 2340 / 2.625), disableAnimations: true),
        child: IntroScreen(onDone: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await _shot('0_intro');
    await tester.pumpAndSettle();
  });

  testWidgets('leer', (tester) async {
    await _pump(tester, FakeChallengeRepository(today: now));
    await _shot('6_leer');
  });
}
