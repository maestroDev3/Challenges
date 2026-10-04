import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/profile_screen.dart';
import 'package:challenges/ui/week_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

/// Montag, 28.09.2026; der Rückblick läuft am Sonntag, 04.10. um 19 Uhr.
final monday = DateTime(2026, 9, 28);
DateTime day(int offset) => monday.add(Duration(days: offset));
final sundayEvening = DateTime(2026, 10, 4, 19, 0);

ActiveChallenge daily(
  String id, {
  int startOffset = 0,
  Iterable<int> done = const [],
  Iterable<int> missed = const [],
  StreakRule rule = StreakRule.relaxed,
}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: day(startOffset),
    reminder: const ReminderTime(7, 0),
    rule: rule,
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  for (final d in missed) {
    c = c.checkIn(day(d), CheckInStatus.missed);
  }
  return c;
}

ActiveChallenge sport(Iterable<int> done) {
  var c = ActiveChallenge(
    id: 'sport',
    template: ChallengeTemplate.custom(
      id: 'custom-sport',
      title: 'Sport',
      kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times),
    ),
    startedOn: day(-7),
    reminder: const ReminderTime(18, 0),
  );
  for (final d in done) {
    c = c.checkIn(day(d), CheckInStatus.done);
  }
  return c;
}

ActiveChallenge nature(Map<int, int> minutes) {
  var c = ActiveChallenge(
    id: 'nature',
    template: templateById('nature-2h')!,
    startedOn: day(-7),
    reminder: const ReminderTime(18, 0),
  );
  for (final e in minutes.entries) {
    c = c.checkIn(day(e.key), CheckInStatus.done, minutes: e.value);
  }
  return c;
}

Widget screen(FakeChallengeRepository repo, {DateTime? now}) =>
    WeekReviewScreen(
      repository: repo,
      weekStart: monday,
      clock: () => now ?? sundayEvening,
    );

void main() {
  testWidgets('zeigt je Challenge eine Karte mit „x von y“',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      daily('meditate-sleep', done: [0, 1, 2, 3, 4, 5], missed: [6]),
      sport([1, 4]),
    ]);
    await tester.pumpApp(screen(repo));
    expect(find.text('Deine Woche'), findsOneWidget);
    expect(find.text('6 von 7'), findsOneWidget);
    expect(find.text('2 von 3'), findsOneWidget);
    expect(find.text('Ziel verfehlt'), findsOneWidget);
    // Gesamt: 8 von 10, Quote 80 %
    expect(find.text('8 von 10'), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);
  });

  testWidgets('die 7-Tage-Leiste unterscheidet erledigt, Joker und verpasst',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      daily(
        'meditate-sleep',
        startOffset: -7,
        rule: StreakRule.joker,
        done: [-7, -6, -5, -4, -3, -2, -1, 0, 1, 3, 4, 6],
        missed: [2],
      ),
    ]);
    final semantics = tester.ensureSemantics();
    await tester.pumpApp(screen(repo));
    // Tag 2 (Mi) vom Joker gerettet, Tag 5 (Sa) ohne Eintrag = verpasst.
    expect(find.bySemanticsLabel(RegExp(r'^Mi.*Joker$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Sa.*verpasst$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Mo.*erledigt$')), findsOneWidget);
    expect(find.text('1 Joker'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('ohne Challenges erscheint ein Leerhinweis', (tester) async {
    await tester.pumpApp(screen(FakeChallengeRepository()));
    expect(find.text('In dieser Woche lief kein Ritual.'), findsOneWidget);
    expect(find.text('Quote'), findsNothing);
  });

  testWidgets('ein in der Woche erreichtes Abzeichen wird genannt',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      daily('meditate-sleep',
          startOffset: -3, done: [-3, -2, -1, 0, 1, 2, 3, 4, 5, 6]),
    ]);
    await tester.pumpApp(screen(repo));
    expect(
      find.text('Neues Abzeichen: 7 Tage · Meditieren vor dem Schlafen'),
      findsOneWidget,
    );
  });

  testWidgets('Minuten aus Wochenzielen stehen als „1 h 50“',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [nature({1: 60, 4: 50})]);
    await tester.pumpApp(screen(repo));
    expect(find.text('1 h 50'), findsOneWidget);
  });

  testWidgets('„Woche abschließen“ schließt den Screen', (tester) async {
    final repo = FakeChallengeRepository(initial: [daily('meditate-sleep')]);
    await tester.pumpApp(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen(repo)),
            ),
            child: const Text('Öffnen'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Deine Woche'), findsOneWidget);
    await tester.tap(find.text('Woche abschließen'));
    await tester.pumpAndSettle();
    expect(find.text('Deine Woche'), findsNothing);
    expect(find.text('Öffnen'), findsOneWidget);
  });

  testWidgets('aus dem Profil öffnet „Letzte Woche ansehen“ den Rückblick',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      daily('meditate-sleep', done: [0, 1, 2, 3, 4, 5, 6]),
    ]);
    await tester.pumpApp(ProfileScreen(
      repository: repo,
      settings: FakeSettingsRepository(const AppSettings(name: 'Mia')),
      clock: () => day(9), // Mittwoch der Folgewoche → vergangene Woche
    ));
    await tester.tap(find.text('Letzte Woche ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('Deine Woche'), findsOneWidget);
    expect(find.text('7 von 7'), findsAtLeastNWidgets(1));
  });

  testWidgets('Texte gibt es auf Englisch und Russisch', (tester) async {
    final repo = FakeChallengeRepository(initial: [daily('meditate-sleep')]);
    await tester.pumpApp(screen(repo), locale: const Locale('en'));
    expect(find.text('Your week'), findsOneWidget);
    expect(find.text('Close the week'), findsOneWidget);
    await tester.pumpApp(screen(repo), locale: const Locale('ru'));
    expect(find.text('Твоя неделя'), findsOneWidget);
    expect(find.text('Завершить неделю'), findsOneWidget);
  });
}
