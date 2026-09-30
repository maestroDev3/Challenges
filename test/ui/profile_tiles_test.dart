import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

/// Handy-Breite in dp (Pixel-Verhältnis 1).
const phone = Size(360, 800);

Future<void> pumpProfile(WidgetTester tester, {Locale locale = const Locale('de')}) =>
    tester.pumpApp(
      ProfileScreen(
        repository: FakeChallengeRepository(initial: [
          ActiveChallenge(
            id: 'w',
            template: templateById('wake-5am')!,
            startedOn: DateTime(2026, 9, 1),
            reminder: const ReminderTime(5, 0),
          ),
        ]),
        settings: FakeSettingsRepository(),
      ),
      size: phone,
      locale: locale,
    );

Rect tileOf(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byKey(const ValueKey('stat-tile'))));

void main() {
  testWidgets('drei Kacheln in der ersten Reihe, zwei in der zweiten',
      (tester) async {
    await pumpProfile(tester);
    final running = tileOf(tester, 'Laufend');
    final completed = tileOf(tester, 'Geschafft');
    final days = tileOf(tester, 'Tage erledigt');
    final streak = tileOf(tester, 'Längste Streak');
    final badges = tileOf(tester, 'Abzeichen');

    expect(completed.top, running.top);
    expect(days.top, running.top);
    expect(streak.top, greaterThan(running.bottom - 1));
    expect(badges.top, streak.top);
    expect(completed.left, greaterThan(running.right));
    expect(days.left, greaterThan(completed.right));
  });

  testWidgets('alle Kacheln gleich breit, eine Reihe gleich hoch',
      (tester) async {
    await pumpProfile(tester);
    final tiles = [
      for (final l in ['Laufend', 'Geschafft', 'Tage erledigt',
          'Längste Streak', 'Abzeichen'])
        tileOf(tester, l),
    ];
    for (final t in tiles) {
      expect(t.width, closeTo(tiles.first.width, 0.5));
    }
    expect(tiles[1].height, tiles[0].height);
    expect(tiles[2].height, tiles[0].height);
    expect(tiles[4].height, tiles[3].height);
  });

  testWidgets('lange russische Beschriftung bricht um statt überzulaufen',
      (tester) async {
    await pumpProfile(tester, locale: const Locale('ru'));
    expect(tester.takeException(), isNull);
    expect(find.text('Самая длинная серия'), findsOneWidget);
  });
}
