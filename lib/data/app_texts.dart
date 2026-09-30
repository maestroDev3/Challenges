import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/language.dart';
import '../l10n/app_localizations.dart';
import 'local_settings_repository.dart';

/// Sprachpakete für Code ohne Oberfläche (Benachrichtigungen, Widget, auch im
/// Hintergrund): gewählte Sprache aus den Einstellungen, sonst das System.
Future<AppLocalizations> loadAppTexts(
  SharedPreferences prefs, {
  List<String>? systemLanguages,
}) async {
  await prefs.reload();
  final settings = await LocalSettingsRepository(prefs).load();
  final system = systemLanguages ??
      [
        for (final locale in PlatformDispatcher.instance.locales)
          locale.languageCode,
      ];
  return lookupAppLocalizations(
      Locale(resolveLanguage(settings.language, system)));
}
