import 'dart:async';
import 'dart:convert';

import 'active_challenge.dart';

/// Persönliche Einstellungen, getrennt vom Challenge-Stand, damit sie ein
/// Wiederherstellen oder Löschen von Challenges nicht berühren.
class AppSettings {
  const AppSettings({
    this.name = '',
    this.defaultReminder,
    this.showIntro = true,
    this.language,
    this.weekReviewEnabled = true,
    this.weekReviewTime = const ReminderTime(19, 0),
  });

  /// Anzeigename im Profil; leer, solange der Nutzer keinen gesetzt hat.
  final String name;

  /// Uhrzeit für neue Challenges ohne eigene passende Uhrzeit; `null` heißt
  /// „je nach Challenge“ (bisheriges Verhalten).
  final ReminderTime? defaultReminder;

  /// Ob beim Start das Intro mit dem Leitsatz erscheint.
  final bool showIntro;

  /// Gewählte Sprache (`de`, `en`, `ru`); `null` heißt Systemsprache.
  final String? language;

  /// Sonntags-Benachrichtigung „Deine Woche“ mit dem Wochenrückblick.
  final bool weekReviewEnabled;

  /// Uhrzeit der Sonntags-Benachrichtigung.
  final ReminderTime weekReviewTime;

  AppSettings copyWith({
    String? name,
    ReminderTime? defaultReminder,
    bool clearDefaultReminder = false,
    bool? showIntro,
    String? language,
    bool clearLanguage = false,
    bool? weekReviewEnabled,
    ReminderTime? weekReviewTime,
  }) =>
      AppSettings(
        name: name ?? this.name,
        defaultReminder: clearDefaultReminder
            ? null
            : defaultReminder ?? this.defaultReminder,
        showIntro: showIntro ?? this.showIntro,
        language: clearLanguage ? null : language ?? this.language,
        weekReviewEnabled: weekReviewEnabled ?? this.weekReviewEnabled,
        weekReviewTime: weekReviewTime ?? this.weekReviewTime,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.name == name &&
      other.defaultReminder == defaultReminder &&
      other.showIntro == showIntro &&
      other.language == language &&
      other.weekReviewEnabled == weekReviewEnabled &&
      other.weekReviewTime == weekReviewTime;

  @override
  int get hashCode => Object.hash(name, defaultReminder, showIntro, language,
      weekReviewEnabled, weekReviewTime);
}

/// Zugriff auf die Einstellungen; heute lokal gespeichert.
abstract interface class SettingsRepository {
  Future<AppSettings> load();

  /// Sofort der aktuelle Stand, danach jede Änderung.
  Stream<AppSettings> watch();

  Future<void> save(AppSettings settings);
}

/// Speicherformat der Einstellungen als JSON.
String encodeSettings(AppSettings settings) => jsonEncode({
      'name': settings.name,
      if (settings.defaultReminder case final reminder?)
        'defaultReminder': {'hour': reminder.hour, 'minute': reminder.minute},
      'showIntro': settings.showIntro,
      'language': ?settings.language,
      'weekReviewEnabled': settings.weekReviewEnabled,
      'weekReviewTime': {
        'hour': settings.weekReviewTime.hour,
        'minute': settings.weekReviewTime.minute,
      },
    });

/// Liest gespeicherte Einstellungen. Beschädigte Daten ergeben die
/// Standardwerte, damit die App auch dann startet.
AppSettings decodeSettings(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) return const AppSettings();
    final reminder = json['defaultReminder'];
    final review = json['weekReviewTime'];
    return AppSettings(
      name: json['name'] as String? ?? '',
      defaultReminder: reminder is Map<String, dynamic>
          ? ReminderTime(reminder['hour'] as int, reminder['minute'] as int)
          : null,
      showIntro: json['showIntro'] as bool? ?? true,
      language: json['language'] as String?,
      weekReviewEnabled: json['weekReviewEnabled'] as bool? ?? true,
      weekReviewTime: review is Map<String, dynamic>
          ? ReminderTime(review['hour'] as int, review['minute'] as int)
          : const ReminderTime(19, 0),
    );
  } on Object catch (_) {
    return const AppSettings();
  }
}

/// Einstellungen nur im Speicher – Standard, wenn keine dauerhafte
/// Speicherung verdrahtet ist (z. B. in Widget-Tests der ganzen App).
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this._current = const AppSettings()]);

  AppSettings _current;
  final _changes = StreamController<AppSettings>.broadcast();

  @override
  Future<AppSettings> load() async => _current;

  @override
  Stream<AppSettings> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _current = settings;
    _changes.add(settings);
  }
}
