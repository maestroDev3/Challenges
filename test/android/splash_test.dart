import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';

String read(String path) => File('$res/$path').readAsStringSync();

void main() {
  test('Launch-Hintergrund ist Ritual-Schwarz (kein weißer Blitz)', () {
    for (final f in [
      'drawable/launch_background.xml',
      'drawable-v21/launch_background.xml',
    ]) {
      expect(read(f), contains('@color/ritual_background'), reason: f);
      expect(read(f), isNot(contains('@android:color/white')), reason: f);
    }
    for (final f in ['values/styles.xml', 'values-night/styles.xml']) {
      expect(read(f), contains('@color/ritual_background'), reason: f);
    }
  });

  test('Android 12+: SplashScreen-API mit Ritual-Hintergrund und Icon', () {
    final v31 = read('values-v31/styles.xml');
    expect(v31, contains('android:windowSplashScreenBackground'));
    expect(v31, contains('@color/ritual_background'));
    expect(v31, contains('android:windowSplashScreenAnimatedIcon'));
  });
}
