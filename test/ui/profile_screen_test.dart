import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/settings.dart';
import 'package:challenges/ui/home_shell.dart';
import 'package:challenges/ui/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 5, 20, 15);

ActiveChallenge running(String templateId, int doneDays) {
  var c = ActiveChallenge(
    id: templateId,
    template: templateById(templateId)!,
    startedOn: DateTime(2026, 9, 1),
    reminder: const ReminderTime(7, 0),
  );
  for (var i = 0; i < doneDays; i++) {
    c = c.checkIn(DateTime(2026, 9, 1 + i), CheckInStatus.done);
  }
  return c;
}

void main() {
  testWidgets('die Navigationsleiste führt zum Profil', (tester) async {
    await tester.pumpApp(HomeShell(
      repository: FakeChallengeRepository(),
      settings: FakeSettingsRepository(const AppSettings(name: 'Mia')),
      clock: () => now,
    ));
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Mia'), findsOneWidget);
  });

  testWidgets('ohne Namen heißt es „Dein Profil“', (tester) async {
    await tester.pumpApp(ProfileScreen(
      repository: FakeChallengeRepository(),
      settings: FakeSettingsRepository(),
    ));
    expect(find.text('Dein Profil'), findsOneWidget);
  });

  testWidgets('Kennzahl-Kacheln gibt es im Profil nicht mehr', (tester) async {
    await tester.pumpApp(ProfileScreen(
      repository: FakeChallengeRepository(initial: [running('wake-5am', 8)]),
      settings: FakeSettingsRepository(),
    ));
    expect(find.text('Laufend'), findsNothing);
    expect(find.text('Tage erledigt'), findsNothing);
    expect(find.text('Letzte Woche ansehen'), findsOneWidget);
  });

  testWidgets('„Letzte Woche ansehen“ erscheint mit der ersten Challenge',
      (tester) async {
    final repo = FakeChallengeRepository();
    await tester.pumpApp(ProfileScreen(
      repository: repo,
      settings: FakeSettingsRepository(),
    ));
    expect(find.text('Letzte Woche ansehen'), findsNothing);
    await repo.start(templateById('cold-shower')!, const ReminderTime(7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Letzte Woche ansehen'), findsOneWidget);
  });

  testWidgets('ohne Challenges erscheint ein Hinweis', (tester) async {
    await tester.pumpApp(ProfileScreen(
      repository: FakeChallengeRepository(),
      settings: FakeSettingsRepository(),
    ));
    expect(find.textContaining('Noch keine Challenges'), findsOneWidget);
    expect(find.text('Letzte Woche ansehen'), findsNothing);
  });

  testWidgets('Namensänderung erscheint sofort', (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpApp(ProfileScreen(
      repository: FakeChallengeRepository(),
      settings: settings,
    ));
    await settings.save(const AppSettings(name: 'Mia'));
    await tester.pumpAndSettle();
    expect(find.text('Mia'), findsOneWidget);
  });
}
