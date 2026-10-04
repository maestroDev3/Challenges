import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/android_backup_files.dart';
import 'data/app_texts.dart';
import 'data/home_widget_updater.dart';
import 'data/local_challenge_repository.dart';
import 'data/local_notification_scheduler.dart';
import 'data/local_settings_repository.dart';
import 'domain/challenge_repository.dart';
import 'domain/reminders.dart';
import 'domain/widget_data.dart';
import 'ui/app.dart';
import 'ui/home_shell.dart';

/// Hält das Homescreen-Widget aktuell (in der gewählten Sprache); Fehler
/// (z. B. kein Widget) sind egal.
Future<void> _refreshWidget(
    ChallengeRepository repository, SharedPreferences prefs) async {
  try {
    final WidgetUpdater widget = HomeWidgetUpdater(() => loadAppTexts(prefs));
    await widget.update(await repository.active(), DateTime.now());
  } on Object catch (_) {
    // Widget ist optional – die App funktioniert ohne.
  }
}

/// Wird von Android aufgerufen, wenn in der Benachrichtigung „Erledigt“ /
/// „Nicht erledigt“ / „Stopp“ getippt wird, während die App nicht läuft.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);
  await handleNotificationAction(
    repository,
    actionId: r.actionId,
    payload: r.payload,
    now: DateTime.now(),
    input: r.input,
  );
  // Termine nach dem Abhaken neu planen (z. B. Wochenziel erreicht).
  try {
    final scheduler = await LocalNotificationScheduler.create(
      onResponse: (_) {},
      onBackgroundResponse: onNotificationActionInBackground,
      texts: () => loadAppTexts(prefs),
      askPermissions: false,
    );
    await _reschedule(repository, scheduler, r.payload);
  } on Object catch (_) {
    // Beim nächsten App-Start wird ohnehin neu geplant.
  }
  await _refreshWidget(repository, prefs);
}

Future<void> _reschedule(
    ChallengeRepository repository, ReminderScheduler scheduler, String? id) async {
  if (id == null) return;
  final c = await repository.byId(id);
  if (c == null) return;
  if (c.isArchived) {
    await scheduler.cancel(c);
  } else {
    await scheduler.schedule(c);
  }
}

/// Wird aufgerufen, wenn im Homescreen-Widget ein Haken getippt wird.
@pragma('vm:entry-point')
Future<void> onWidgetTapped(Uri? uri) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);
  await handleWidgetTap(repository, uri, now: DateTime.now());
  await _refreshWidget(repository, prefs);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);

  final navigatorKey = GlobalKey<NavigatorState>();
  late final LocalNotificationScheduler scheduler;
  scheduler = await LocalNotificationScheduler.create(
    onResponse: (r) async {
      if (isWeekReviewPayload(r.payload)) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          openWeekReview(context, repository, DateTime.now);
        }
        return;
      }
      await handleNotificationAction(
        repository,
        actionId: r.actionId,
        payload: r.payload,
        now: DateTime.now(),
        input: r.input,
      );
      await _reschedule(repository, scheduler, r.payload);
    },
    onBackgroundResponse: onNotificationActionInBackground,
    texts: () => loadAppTexts(prefs),
  );
  final settings = LocalSettingsRepository(prefs);
  final initialSettings = await settings.load();
  await syncReminders(repository, scheduler,
      now: DateTime.now(), settings: initialSettings);

  await HomeWidget.registerInteractivityCallback(onWidgetTapped);
  repository.watch().listen((_) async {
    await _refreshWidget(repository, prefs);
    // Letzte Challenge archiviert → keine Sonntags-Benachrichtigung mehr.
    await syncWeekReview(repository, scheduler,
        now: DateTime.now(), settings: await settings.load());
  });

  // Sprachwechsel: Widget-Texte sofort anpassen.
  settings.watch().skip(1).listen((_) => _refreshWidget(repository, prefs));
  final openWeekReview = await scheduler.launchedByWeekReview();

  runApp(ChallengesApp(
    repository: repository,
    scheduler: scheduler,
    backupFiles: const AndroidBackupFiles(),
    settings: settings,
    showIntro: initialSettings.showIntro && !openWeekReview,
    openWeekReview: openWeekReview,
    navigatorKey: navigatorKey,
  ));
}
