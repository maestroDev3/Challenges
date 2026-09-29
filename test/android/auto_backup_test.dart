import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const appMain = 'android/app/src/main';

void main() {
  final manifest = File('$appMain/AndroidManifest.xml').readAsStringSync();

  test('Manifest aktiviert Auto-Backup mit eigenen Regeln', () {
    expect(manifest, contains('android:allowBackup="true"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });

  test('Regeln schließen die gespeicherten Challenges ein', () {
    final legacy = File('$appMain/res/xml/backup_rules.xml').readAsStringSync();
    expect(legacy, contains('<full-backup-content>'));
    expect(legacy,
        contains('<include domain="sharedpref" path="FlutterSharedPreferences.xml"'));

    final rules =
        File('$appMain/res/xml/data_extraction_rules.xml').readAsStringSync();
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    expect(
        RegExp('<include domain="sharedpref" path="FlutterSharedPreferences.xml"')
            .allMatches(rules)
            .length,
        2);
  });

  test('keine neue Berechtigung', () {
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
  });
}
