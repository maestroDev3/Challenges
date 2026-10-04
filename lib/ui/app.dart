import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/language.dart';
import '../domain/reminders.dart';
import '../domain/settings.dart';
import '../l10n/app_localizations.dart';
import 'home_shell.dart';
import 'intro_screen.dart';
import 'theme.dart';

class ChallengesApp extends StatefulWidget {
  const ChallengesApp({
    super.key,
    required this.repository,
    this.scheduler,
    this.backupFiles,
    this.settings,
    this.showIntro = true,
    this.clock = DateTime.now,
    this.openWeekReview = false,
    this.navigatorKey,
  });

  final ChallengeRepository repository;
  final ReminderScheduler? scheduler;
  final BackupFiles? backupFiles;
  final SettingsRepository? settings;

  /// Intro mit Leitsatz beim Start; aus den Einstellungen (in `main` geladen).
  final bool showIntro;

  /// Uhr für „heute“ – in Tests fest.
  final Clock clock;

  /// Beim Start direkt den Wochenrückblick öffnen (Start per
  /// Benachrichtigung).
  final bool openWeekReview;

  /// Erlaubt `main`, bei getippter Benachrichtigung zu navigieren.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<ChallengesApp> createState() => _ChallengesAppState();
}

class _ChallengesAppState extends State<ChallengesApp> {
  /// Ohne übergebene Einstellungen (Tests) gilt ein Stand im Speicher, den
  /// Shell und Einstellungen gemeinsam nutzen.
  late final SettingsRepository _settings =
      widget.settings ?? MemorySettingsRepository();
  late final Stream<AppSettings> _settingsStream = _settings.watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      stream: _settingsStream,
      builder: (context, snapshot) {
        final systemLanguages = [
          for (final locale
              in WidgetsBinding.instance.platformDispatcher.locales)
            locale.languageCode,
        ];
        final language =
            resolveLanguage(snapshot.data?.language, systemLanguages);
        return MaterialApp(
          title: 'Ritual',
          navigatorKey: widget.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildTheme(),
          themeMode: ThemeMode.dark,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _IntroGate(
            showIntro: widget.showIntro,
            child: HomeShell(
              repository: widget.repository,
              clock: widget.clock,
              scheduler: widget.scheduler,
              backupFiles: widget.backupFiles,
              settings: _settings,
              openWeekReview: widget.openWeekReview,
            ),
          ),
        );
      },
    );
  }
}

/// Zeigt einmal pro Start das Intro und blendet dann in die App über.
class _IntroGate extends StatefulWidget {
  const _IntroGate({required this.child, required this.showIntro});

  final bool showIntro;

  final Widget child;

  @override
  State<_IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<_IntroGate> {
  late bool _introDone = !widget.showIntro;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _introDone
          ? widget.child
          : IntroScreen(onDone: () => setState(() => _introDone = true)),
    );
  }
}
