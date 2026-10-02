import 'package:challenges/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daysCount', () {
    test('Deutsch: 1 Tag, sonst Tage', () {
      final de = lookupAppLocalizations(const Locale('de'));
      expect(de.daysCount(1), '1 Tag');
      expect(de.daysCount(5), '5 Tage');
    });

    test('Englisch: 1 day, sonst days', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.daysCount(1), '1 day');
      expect(en.daysCount(2), '2 days');
    });

    test('Russisch: день / дня / дней', () {
      final ru = lookupAppLocalizations(const Locale('ru'));
      expect(ru.daysCount(1), '1 день');
      expect(ru.daysCount(2), '2 дня');
      expect(ru.daysCount(5), '5 дней');
      expect(ru.daysCount(11), '11 дней');
      expect(ru.daysCount(21), '21 день');
    });
  });

  test('Russisch: Anzahlen in der Backup-Abfrage', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.backupCountActive(1), '1 активный челлендж');
    expect(ru.backupCountActive(3), '3 активных челленджа');
    expect(ru.backupCountActive(5), '5 активных челленджей');
  });

  test('Russisch: Tage bis zum Start', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.startsTomorrow, 'завтра');
    expect(ru.startsIn(2), 'через 2 дня');
    expect(ru.startsIn(5), 'через 5 дней');
    expect(ru.startsIn(21), 'через 21 день');
  });
}
