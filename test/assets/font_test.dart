import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/font_cmap.dart';

const fonts = [
  'CormorantGaramond-Regular.ttf',
  'CormorantGaramond-Medium.ttf',
  'CormorantGaramond-SemiBold.ttf',
  'CormorantGaramond-Italic.ttf',
  'CormorantGaramond-MediumItalic.ttf',
];

void main() {
  test('alle Schnitte der Serifenschrift enthalten Kyrillisch', () {
    for (final font in fonts) {
      final codePoints = fontCodePoints('assets/fonts/$font');
      for (final char in ['Д', 'я', 'ё', 'Ж', 'щ']) {
        expect(codePoints, contains(char.codeUnitAt(0)),
            reason: '$font: $char fehlt');
      }
    }
  });

  test('Lateinisch mit Umlauten bleibt erhalten', () {
    for (final font in fonts) {
      final codePoints = fontCodePoints('assets/fonts/$font');
      for (final char in ['A', 'z', 'ä', 'ö', 'ü', 'ß', '„', '“', '–']) {
        expect(codePoints, contains(char.codeUnitAt(0)),
            reason: '$font: $char fehlt');
      }
    }
  });

  test('die Lizenz (OFL) liegt bei', () {
    expect(File('assets/fonts/OFL-CormorantGaramond.txt').existsSync(), isTrue);
  });
}
