import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const appMain = 'android/app/src/main';

void main() {
  test('Widget-Provider und Hintergrund-Empfänger sind registriert', () {
    final manifest = File('$appMain/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('.RitualWidgetProvider'));
    expect(manifest, contains('android.appwidget.action.APPWIDGET_UPDATE'));
    expect(manifest, contains('@xml/ritual_widget_info'));
    expect(manifest,
        contains('es.antonborri.home_widget.HomeWidgetBackgroundReceiver'));
    expect(manifest,
        contains('es.antonborri.home_widget.HomeWidgetBackgroundService'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('Provider, Layout und Widget-Info existieren', () {
    final provider = File(
            '$appMain/kotlin/de/maestrodev/challenges/RitualWidgetProvider.kt')
        .readAsStringSync();
    expect(provider, contains('class RitualWidgetProvider'));
    expect(provider, contains('ritual://check?id='));
    final layout = File('$appMain/res/layout/ritual_widget.xml').readAsStringSync();
    for (var i = 0; i < 4; i++) {
      expect(layout, contains('@+id/row_$i'));
      expect(layout, contains('@+id/check_$i'));
    }
    expect(File('$appMain/res/xml/ritual_widget_info.xml').existsSync(), isTrue);
  });
}
