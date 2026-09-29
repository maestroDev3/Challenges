import 'package:challenges/data/local_settings_repository.dart';
import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalSettingsRepository> newRepo() async =>
      LocalSettingsRepository(await SharedPreferences.getInstance());

  group('LocalSettingsRepository', () {
    test('ohne gespeicherte Daten gibt es Standardwerte', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await (await newRepo()).load(), const AppSettings());
    });

    test('Gespeichertes wird wieder gelesen', () async {
      SharedPreferences.setMockInitialValues({});
      const settings = AppSettings(
          name: 'Mia', defaultReminder: ReminderTime(6, 30), showIntro: false);
      await (await newRepo()).save(settings);
      expect(await (await newRepo()).load(), settings);
    });

    test('watch liefert sofort den Stand und danach jede Änderung', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await newRepo();
      final seen = <AppSettings>[];
      final sub = repo.watch().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await repo.save(const AppSettings(name: 'Mia'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [const AppSettings(), const AppSettings(name: 'Mia')]);
    });

    test('beschädigte Daten führen zu Standardwerten', () async {
      SharedPreferences.setMockInitialValues({'settings_v1': 'kaputt'});
      expect(await (await newRepo()).load(), const AppSettings());
    });

    test('Challenge-Daten bleiben unberührt', () async {
      SharedPreferences.setMockInitialValues({'challenges_v2': '{"x":1}'});
      await (await newRepo()).save(const AppSettings(name: 'Mia'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('challenges_v2'), '{"x":1}');
    });
  });
}
