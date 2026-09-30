import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings.dart';

/// Speichert die Einstellungen unter einem eigenen Schlüssel in
/// shared_preferences – unabhängig vom Challenge-Stand.
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._prefs);

  static const _key = 'settings_v1';

  final SharedPreferences _prefs;
  final _changes = StreamController<AppSettings>.broadcast();

  @override
  Future<AppSettings> load() async {
    final raw = _prefs.getString(_key);
    return raw == null ? const AppSettings() : decodeSettings(raw);
  }

  @override
  Stream<AppSettings> watch() async* {
    yield await load();
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_key, encodeSettings(settings));
    _changes.add(settings);
  }
}
