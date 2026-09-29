import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Release-APKs werden von R8 verkleinert. Ohne Regel entfernt R8 die von Room
// generierte WorkDatabase_Impl (WorkManager kommt über home_widget) und die
// App stürzt beim Start ab (#94).
void main() {
  test('Release-Build nutzt die eigenen R8-Regeln', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('proguardFiles('));
    expect(gradle, contains('"proguard-rules.pro"'));
  });

  test('R8-Regeln behalten Room-Datenbanken für WorkManager', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('androidx.room.RoomDatabase'));
    expect(rules, contains('androidx.work.impl.WorkDatabase_Impl'));
  });

  test('Emulator-Starttest ist Teil der CI', () {
    final smoke = File('.github/workflows/smoke.yml').readAsStringSync();
    expect(smoke, contains('scripts/emulator.sh'));
    expect(File('scripts/smoke_test.sh').readAsStringSync(),
        contains('FATAL EXCEPTION'));
  });
}
