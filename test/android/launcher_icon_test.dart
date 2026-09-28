import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';

/// Breite und Höhe aus dem PNG-Header (IHDR).
(int, int) pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  test('Adaptive Icon mit Vordergrund, Hintergrund und Monochrom', () {
    final xml =
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(xml, contains('<adaptive-icon'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('@color/ic_launcher_background'));
    expect(xml, contains('<monochrome'));
    final colors = File('$res/values/colors.xml').readAsStringSync();
    expect(colors, contains('#0F0E0C'));
  });

  test('PNGs in allen Dichten', () {
    const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    const adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    legacy.forEach((d, px) {
      expect(pngSize('$res/mipmap-$d/ic_launcher.png'), (px, px), reason: d);
    });
    adaptive.forEach((d, px) {
      for (final name in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
        expect(pngSize('$res/drawable-$d/$name.png'), (px, px),
            reason: '$d/$name');
      }
    });
  });

  test('App-Name auf dem Homescreen ist „Ritual“', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="Ritual"'));
  });
}
