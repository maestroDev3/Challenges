import 'dart:async';

import 'package:challenges/domain/settings.dart';

/// Einstellungen im Speicher; [current] ist der zuletzt gespeicherte Stand.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this.current = const AppSettings()]);

  AppSettings current;
  final _changes = StreamController<AppSettings>.broadcast();

  @override
  Future<AppSettings> load() async => current;

  @override
  Stream<AppSettings> watch() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    current = settings;
    _changes.add(settings);
  }
}
