import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/detail_screen.dart';
import 'package:challenges/ui/format.dart';
import 'package:challenges/l10n/template_text.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 9, 10);
final de = lookupAppLocalizations(const Locale('de'));
final en = lookupAppLocalizations(const Locale('en'));
final ru = lookupAppLocalizations(const Locale('ru'));

ActiveChallenge running(String templateId) => ActiveChallenge(
      id: templateId,
      template: templateById(templateId)!,
      startedOn: DateTime(2026, 10, 5),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  group('Vorlagentexte', () {
    test('alle Katalog-Vorlagen haben Titel und Beschreibung in DE/EN/RU', () {
      for (final t in challengeCatalog) {
        for (final l10n in [de, en, ru]) {
          expect(t.titleIn(l10n), isNotEmpty, reason: t.id);
          expect(t.descriptionIn(l10n), isNotEmpty, reason: t.id);
        }
        expect(t.titleIn(de), t.title, reason: 'Deutsch = gespeicherter Text');
        expect(t.titleIn(en), isNot(t.title), reason: t.id);
        expect(t.titleIn(ru), isNot(t.title), reason: t.id);
      }
    });

    test('eigene Vorlagen zeigen den Text des Nutzers unverändert', () {
      final own = ChallengeTemplate.custom(
          title: 'Lesen', description: 'Jeden Abend', kind: const DailyKind());
      expect(own.titleIn(en), 'Lesen');
      expect(own.descriptionIn(ru), 'Jeden Abend');
    });

    test('Schritte der Morgenroutine sind übersetzt, Reihenfolge bleibt', () {
      final t = templateById('morning-routine')!;
      expect(t.stepsIn(en), hasLength(t.steps.length));
      expect(t.stepsIn(en).first, 'Drink a glass of water');
      expect(t.stepsIn(de), t.steps);
    });
  });

  group('Arten und Datum', () {
    test('Challenge-Arten auf Englisch und Russisch', () {
      expect(kindLabelIn(en, const DailyKind(days: 30)), '30 days');
      expect(kindLabelIn(ru, const DailyKind(days: 21)), '21 день');
      expect(kindLabelIn(en, const DailyKind()), 'daily');
      expect(kindLabelIn(en, const WeeklyGoalKind(120)), '2 h/week');
      expect(
          kindLabelIn(en,
              const WeeklyGoalKind(3, unit: WeeklyUnit.times, weekdays: {1, 3, 5})),
          '3×/week · Mon Wed Fri');
      expect(kindLabelIn(de, const DailyKind(days: 66)), '66 Tage');
    });

    test('Wochentage und Monate folgen der Sprache', () {
      final day = DateTime(2026, 10, 5); // Montag
      expect(formatWeekdayDate(de, day), 'Mo, 05.10.');
      expect(formatWeekdayDate(en, day), 'Mon, 05/10');
      expect(formatWeekdayDate(ru, day), 'Пн, 05.10');
      expect(formatMonth(en, day), 'October 2026');
      expect(formatMonth(ru, day), 'Октябрь 2026');
      expect(formatDate(de, day, withYear: true), '05.10.2026');
    });
  });

  testWidgets('Katalog auf Englisch zeigt übersetzte Vorlagen', (tester) async {
    await tester.pumpApp(CatalogScreen(repository: FakeChallengeRepository()),
        locale: const Locale('en'), size: const Size(900, 3200));
    expect(find.text('Wake up at 5 am'), findsOneWidget);
    expect(find.text('Um 5 Uhr aufstehen'), findsNothing);
  });

  testWidgets('Katalog auf Russisch', (tester) async {
    await tester.pumpApp(CatalogScreen(repository: FakeChallengeRepository()),
        locale: const Locale('ru'), size: const Size(900, 3200));
    expect(find.text('Подъём в 5 утра'), findsOneWidget);
  });

  testWidgets('Heute auf Englisch: Titel und Schritte übersetzt, gespeichert '
      'bleibt Deutsch', (tester) async {
    final repo = FakeChallengeRepository(initial: [running('morning-routine')]);
    await tester.pumpApp(
      TodayScreen(repository: repo, onDiscover: () {}, clock: () => today),
      locale: const Locale('en'),
    );
    expect(find.text('Daily morning routine'), findsOneWidget);
    expect(find.text('Drink a glass of water'), findsOneWidget);
    expect(repo.items.single.template.title, 'Tägliche Morgenroutine');
  });

  testWidgets('Detail auf Englisch: Monat und Art', (tester) async {
    await tester.pumpApp(
      ChallengeDetailScreen(challenge: running('wake-5am'), clock: () => today),
      locale: const Locale('en'),
    );
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('30 days · since 05/10/2026'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
  });
}
