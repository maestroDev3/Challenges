import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/adjust_sheet.dart';
import 'package:challenges/ui/archive_screen.dart';
import 'package:challenges/ui/detail_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 9, 10);
const english = Locale('en');
const russian = Locale('ru');

ActiveChallenge wake({int doneDays = 3}) {
  var c = ActiveChallenge(
    id: 'wake-5am',
    template: templateById('wake-5am')!,
    startedOn: DateTime(2026, 10, 5),
    reminder: const ReminderTime(5, 0),
  );
  for (var d = 0; d < doneDays; d++) {
    c = c.checkIn(DateTime(2026, 10, 5 + d), CheckInStatus.done);
  }
  return c;
}

void main() {
  testWidgets('Heute auf Englisch: Leerzustand', (tester) async {
    await tester.pumpApp(
      TodayScreen(
          repository: FakeChallengeRepository(),
          onDiscover: () {},
          clock: () => today),
      locale: english,
    );
    expect(find.text('Today'), findsWidgets);
    expect(find.text('No active challenge yet'), findsOneWidget);
    expect(find.text('Find a challenge'), findsOneWidget);
  });

  testWidgets('Heute auf Englisch: Karte mit Check-in', (tester) async {
    await tester.pumpApp(
      TodayScreen(
          repository: FakeChallengeRepository(initial: [wake()]),
          onDiscover: () {},
          clock: () => today),
      locale: english,
    );
    expect(find.text('Done'), findsWidgets);
    expect(find.text('Not done'), findsWidgets);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('Heute auf Russisch: Leerzustand', (tester) async {
    await tester.pumpApp(
      TodayScreen(
          repository: FakeChallengeRepository(),
          onDiscover: () {},
          clock: () => today),
      locale: russian,
    );
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Найти челлендж'), findsOneWidget);
  });

  testWidgets('Detail auf Englisch', (tester) async {
    await tester.pumpApp(
      ChallengeDetailScreen(challenge: wake(doneDays: 8), clock: () => today),
      locale: english,
    );
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('Success rate'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
  });

  testWidgets('Archiv auf Englisch: Leerzustand', (tester) async {
    await tester.pumpApp(
      ArchiveScreen(repository: FakeChallengeRepository()),
      locale: english,
    );
    expect(find.text('Nothing finished yet'), findsOneWidget);
  });

  testWidgets('Anpassen auf Englisch', (tester) async {
    await tester.pumpApp(
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showAdjustSheet(
              context,
              challenge: wake(),
              repository: FakeChallengeRepository(initial: [wake()]),
              clock: () => today,
            ),
            child: const Text('open'),
          ),
        ),
      ),
      locale: english,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('History and streak are kept.'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
