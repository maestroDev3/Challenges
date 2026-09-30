import 'package:challenges/domain/language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLanguage', () {
    test('die gewählte Sprache gewinnt', () {
      expect(resolveLanguage('ru', ['en', 'de']), 'ru');
    });

    test('ohne Wahl gilt die erste unterstützte Systemsprache', () {
      expect(resolveLanguage(null, ['fr', 'en', 'de']), 'en');
      expect(resolveLanguage(null, ['ru']), 'ru');
    });

    test('sonst Deutsch', () {
      expect(resolveLanguage(null, ['fr', 'es']), 'de');
      expect(resolveLanguage(null, []), 'de');
    });

    test('unbekannte gespeicherte Sprache fällt auf das System zurück', () {
      expect(resolveLanguage('xx', ['en']), 'en');
    });
  });
}
