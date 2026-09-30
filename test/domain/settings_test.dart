import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('Standardwerte: kein Name, Erinnerung je Challenge, Intro an', () {
      const settings = AppSettings();
      expect(settings.name, '');
      expect(settings.defaultReminder, isNull);
      expect(settings.showIntro, isTrue);
      expect(settings.language, isNull);
    });

    test('Sprache setzen und auf Systemsprache zurücksetzen', () {
      const settings = AppSettings(language: 'en');
      expect(settings.copyWith(language: 'ru').language, 'ru');
      expect(settings.copyWith(clearLanguage: true).language, isNull);
    });

    test('copyWith ändert nur die angegebenen Werte', () {
      const settings = AppSettings(name: 'Mia');
      final changed = settings.copyWith(
          defaultReminder: const ReminderTime(6, 30), showIntro: false);
      expect(changed.name, 'Mia');
      expect(changed.defaultReminder, const ReminderTime(6, 30));
      expect(changed.showIntro, isFalse);
    });

    test('copyWith kann die Standard-Erinnerung zurücksetzen', () {
      const settings = AppSettings(defaultReminder: ReminderTime(6, 30));
      expect(settings.copyWith(clearDefaultReminder: true).defaultReminder,
          isNull);
    });
  });

  group('encodeSettings/decodeSettings', () {
    test('Speichern und Lesen ergibt dieselben Werte', () {
      const settings = AppSettings(
          name: 'Mia',
          defaultReminder: ReminderTime(6, 30),
          showIntro: false,
          language: 'ru');
      expect(decodeSettings(encodeSettings(settings)), settings);
    });

    test('ohne Erinnerung bleibt sie null', () {
      const settings = AppSettings(name: 'Mia');
      expect(decodeSettings(encodeSettings(settings)), settings);
    });

    test('gespeicherte Einstellungen ohne Sprache laden weiter', () {
      final old = decodeSettings(
          '{"name":"Mia","defaultReminder":{"hour":6,"minute":30},"showIntro":false}');
      expect(old.name, 'Mia');
      expect(old.defaultReminder, const ReminderTime(6, 30));
      expect(old.showIntro, isFalse);
      expect(old.language, isNull);
    });

    test('beschädigte Daten ergeben Standardwerte', () {
      expect(decodeSettings('kaputt'), const AppSettings());
      expect(decodeSettings('{"name": 3}'), const AppSettings());
      expect(decodeSettings('[]'), const AppSettings());
    });
  });
}
