import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const appMain = 'android/app/src/main';

void main() {
  test('MainActivity bedient den Datei-Kanal über die Android-Dateiauswahl', () {
    final activity =
        File('$appMain/kotlin/de/maestrodev/challenges/MainActivity.kt')
            .readAsStringSync();
    expect(activity, contains('"ritual/backup_files"'));
    expect(activity, contains('ACTION_CREATE_DOCUMENT'));
    expect(activity, contains('ACTION_OPEN_DOCUMENT'));
  });

  test('keine Speicher- oder Internet-Berechtigung nötig', () {
    final manifest = File('$appMain/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
  });
}
