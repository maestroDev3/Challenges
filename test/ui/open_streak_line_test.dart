import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

/// Donnerstag, 8.10.2026, abends.
final now = DateTime(2026, 10, 8, 20, 0);

ActiveChallenge withStreak(int days, {String id = 'meditate-sleep'}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: DateTime(2026, 9, 28),
    reminder: const ReminderTime(7, 0),
  );
  for (var i = 0; i < days; i++) {
    c = c.checkIn(DateTime(2026, 10, 7 - i), CheckInStatus.done);
  }
  return c;
}

void main() {
  testWidgets('offene Serie ab 3 Tagen erscheint als Zeile', (tester) async {
    final repo = FakeChallengeRepository(initial: [withStreak(5)]);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now));
    expect(find.text('Meditieren vor dem Schlafen: heute noch offen'),
        findsOneWidget);
    expect(find.text('Serie 5'), findsOneWidget);
  });

  testWidgets('nach dem Abhaken verschwindet die Zeile', (tester) async {
    final repo = FakeChallengeRepository(initial: [withStreak(5)]);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now));
    await repo.save(withStreak(5).checkIn(now, CheckInStatus.done));
    await tester.pumpAndSettle();
    expect(find.textContaining('heute noch offen'), findsNothing);
  });

  testWidgets('Serie 2: keine Zeile', (tester) async {
    final repo = FakeChallengeRepository(initial: [withStreak(2)]);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now));
    expect(find.textContaining('heute noch offen'), findsNothing);
  });

  testWidgets('Tippen auf die Zeile öffnet die Detailansicht', (tester) async {
    final repo = FakeChallengeRepository(initial: [withStreak(5)]);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now));
    await tester
        .tap(find.text('Meditieren vor dem Schlafen: heute noch offen'));
    await tester.pumpAndSettle();
    expect(find.text('Beste Streak'), findsOneWidget);
  });

  testWidgets('Englisch und Russisch', (tester) async {
    final repo = FakeChallengeRepository(initial: [withStreak(5)]);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now),
        locale: const Locale('en'));
    expect(
        find.text('Meditate before sleep: still open today'), findsOneWidget);
    await tester.pumpApp(StatisticsScreen(repository: repo, clock: () => now),
        locale: const Locale('ru'));
    expect(find.text('Медитация перед сном: сегодня ещё открыт'),
        findsOneWidget);
  });
}
