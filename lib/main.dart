import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_challenge_repository.dart';
import 'data/local_notification_scheduler.dart';
import 'domain/reminders.dart';
import 'ui/app.dart';

/// Wird von Android aufgerufen, wenn in der Benachrichtigung „Erledigt“ /
/// „Nicht erledigt“ getippt wird, während die App nicht läuft.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await handleNotificationAction(
    LocalChallengeRepository(prefs),
    actionId: r.actionId,
    payload: r.payload,
    now: DateTime.now(),
    input: r.input,
  );
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
  await syncReminders(repository, scheduler);

  runApp(ChallengesApp(repository: repository, scheduler: scheduler));
}
