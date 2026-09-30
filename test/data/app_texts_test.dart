import 'package:challenges/data/app_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gewählte Sprache aus den Einstellungen gilt auch im Hintergrund',
      () async {
    SharedPreferences.setMockInitialValues(
        {'settings_v1': '{"name":"","showIntro":true,"language":"ru"}'});
    final texts = await loadAppTexts(await SharedPreferences.getInstance(),
        systemLanguages: ['de']);
    expect(texts.localeName, 'ru');
  });

  test('ohne Wahl gilt die Systemsprache', () async {
    SharedPreferences.setMockInitialValues({});
    final texts = await loadAppTexts(await SharedPreferences.getInstance(),
        systemLanguages: ['en', 'de']);
    expect(texts.localeName, 'en');
  });
}
