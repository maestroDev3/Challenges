import 'package:challenges/ui/app.dart';
import 'package:challenges/ui/intro_screen.dart';
import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

Future<void> pumpIntro(WidgetTester tester, VoidCallback onDone,
    {bool reduceMotion = false}) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: IntroScreen(onDone: onDone),
    ),
  ));
}

void main() {
  group('IntroScreen', () {
    testWidgets('zeigt Name und Leitsatz', (tester) async {
      await pumpIntro(tester, () {});
      expect(find.text('RITUAL'), findsOneWidget);
      expect(find.text('Sacrifice the moment.'), findsOneWidget);
      expect(find.text('Evolve the future.'), findsOneWidget);
      expect(find.byType(RitualLogo), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('endet nach Ablauf genau einmal', (tester) async {
      var done = 0;
      await pumpIntro(tester, () => done++);
      await tester.pump(const Duration(milliseconds: 500));
      expect(done, 0);
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('Tippen überspringt', (tester) async {
      var done = 0;
      await pumpIntro(tester, () => done++);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(IntroScreen));
      await tester.pump();
      expect(done, 1);
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('weniger Bewegung: Ring sofort vollständig', (tester) async {
      await pumpIntro(tester, () {}, reduceMotion: true);
      await tester.pump();
      final logo = tester.widget<RitualLogo>(find.byType(RitualLogo));
      expect(logo.progress, 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('mit Animation wächst der Ring', (tester) async {
      await pumpIntro(tester, () {});
      await tester.pump();
      final start = tester.widget<RitualLogo>(find.byType(RitualLogo)).progress;
      await tester.pump(const Duration(milliseconds: 400));
      final later = tester.widget<RitualLogo>(find.byType(RitualLogo)).progress;
      expect(start, lessThan(later));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('App startet mit Intro und zeigt danach „Heute“', (tester) async {
    await tester.pumpWidget(ChallengesApp(repository: FakeChallengeRepository()));
    await tester.pump();
    expect(find.text('RITUAL'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('RITUAL'), findsNothing);
    expect(find.text('Heute'), findsWidgets);
  });
}
