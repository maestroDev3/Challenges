import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/backup_files.dart';
import '../domain/challenge_repository.dart';
import '../domain/reminders.dart';
import '../domain/settings.dart';
import '../domain/week_review.dart';
import 'catalog_screen.dart';
import 'l10n.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'week_review_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.scheduler,
    this.backupFiles,
    this.settings,
    this.openWeekReview = false,
  });

  final ChallengeRepository repository;
  final Clock clock;

  /// Nach dem ersten Aufbau den Wochenrückblick öffnen.
  final bool openWeekReview;

  /// Plant/storniert Erinnerungen; null in Tests ohne Erinnerungen.
  final ReminderScheduler? scheduler;

  /// Datei-Dialog für „Daten sichern“; null in Tests ohne Dateien.
  final BackupFiles? backupFiles;

  /// Einstellungen für Profil; null in Tests ohne Einstellungen.
  final SettingsRepository? settings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Ersatz, wenn keine Einstellungen übergeben wurden (nur in Tests).
  late final SettingsRepository _defaultSettings = MemorySettingsRepository();

  /// Einmal abonniert, damit Neuaufbauten der Shell nicht neu abonnieren.
  late final Stream<AppSettings> _settingsStream =
      (widget.settings ?? _defaultSettings).watch();
  int _tab = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        widget.repository.refresh();
        setState(() {}); // neues „Heute“, falls über Mitternacht
      },
    );
    if (widget.openWeekReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        openWeekReview(context, widget.repository, widget.clock);
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(
            repository: widget.repository,
            clock: widget.clock,
            onDiscover: () => setState(() => _tab = 1),
            scheduler: widget.scheduler,
          ),
          StreamBuilder<AppSettings>(
            stream: _settingsStream,
            builder: (context, snapshot) => CatalogScreen(
              repository: widget.repository,
              clock: widget.clock,
              defaultReminder: snapshot.data?.defaultReminder,
              onStarted: (c) async {
                await widget.scheduler?.schedule(c);
                if (mounted) setState(() => _tab = 0);
              },
            ),
          ),
          ProfileScreen(
            repository: widget.repository,
            settings: widget.settings ?? _defaultSettings,
            clock: widget.clock,
            onOpenSettings: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  settings: widget.settings ?? _defaultSettings,
                  repository: widget.repository,
                  backupFiles: widget.backupFiles,
                  scheduler: widget.scheduler,
                  clock: widget.clock,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: context.l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: context.l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

/// Öffnet den Rückblick auf die passende Woche (sonntags die laufende).
void openWeekReview(
    BuildContext context, ChallengeRepository repository, Clock clock) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WeekReviewScreen(
        repository: repository,
        weekStart: reviewWeekFor(clock()),
        clock: clock,
      ),
    ),
  );
}
