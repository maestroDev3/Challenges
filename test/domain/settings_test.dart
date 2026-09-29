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
          name: 'Mia', defaultReminder: ReminderTime(6, 30), showIntro: false);
      expect(decodeSettings(encodeSettings(settings)), settings);
    });

    test('ohne Erinnerung bleibt sie null', () {
      const settings = AppSettings(name: 'Mia');
      expect(decodeSettings(encodeSettings(settings)), settings);
    });

    test('beschädigte Daten ergeben Standardwerte', () {
      expect(decodeSettings('kaputt'), const AppSettings());
      expect(decodeSettings('{"name": 3}'), const AppSettings());
      expect(decodeSettings('[]'), const AppSettings());
    });
  });
}
