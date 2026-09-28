import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/home_widget_updater.dart';
import 'data/local_challenge_repository.dart';
import 'data/local_notification_scheduler.dart';
import 'domain/challenge_repository.dart';
import 'domain/reminders.dart';
import 'domain/widget_data.dart';
import 'ui/app.dart';

const WidgetUpdater _widget = HomeWidgetUpdater();

/// Hält das Homescreen-Widget aktuell; Fehler (z. B. kein Widget) sind egal.
Future<void> _refreshWidget(ChallengeRepository repository) async {
  try {
    await _widget.update(await repository.active(), DateTime.now());
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
  await _refreshWidget(repository);
}

/// Wird aufgerufen, wenn im Homescreen-Widget ein Haken getippt wird.
@pragma('vm:entry-point')
Future<void> onWidgetTapped(Uri? uri) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);
  await handleWidgetTap(repository, uri, now: DateTime.now());
  await _refreshWidget(repository);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);

  final scheduler = await LocalNotificationScheduler.create(
    onResponse: (r) => handleNotificationAction(
      repository,
      actionId: r.actionId,
      payload: r.payload,
      now: DateTime.now(),
      input: r.input,
    ),
    onBackgroundResponse: onNotificationActionInBackground,
  );
  await syncReminders(repository, scheduler, now: DateTime.now());

  await HomeWidget.registerInteractivityCallback(onWidgetTapped);
  repository.watch().listen((_) => _refreshWidget(repository));

  runApp(ChallengesApp(repository: repository, scheduler: scheduler));
}
