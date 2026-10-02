import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/active_challenge.dart';
import '../domain/reminders.dart';
import '../l10n/app_localizations.dart';
import '../l10n/background_texts.dart';
import '../l10n/template_text.dart';

typedef NotificationResponseHandler = void Function(NotificationResponse);

/// Liefert die Sprachpakete in der aktuell gewählten Sprache.
typedef TextsLoader = Future<AppLocalizations> Function();

/// Android-Implementierung mit flutter_local_notifications.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin, this._texts,
      {required bool askPermissions})
      : _permissionAsked = !askPermissions;

  final FlutterLocalNotificationsPlugin _plugin;
  final TextsLoader _texts;
  bool _permissionAsked;

  static const _channelId = 'challenge_reminders';
  static const _sessionChannelId = 'challenge_sessions';

  static Future<LocalNotificationScheduler> create({
    required NotificationResponseHandler onResponse,
    required NotificationResponseHandler onBackgroundResponse,
    required TextsLoader texts,
    // Im Hintergrund (keine Activity) nicht nach Berechtigungen fragen.
    bool askPermissions = true,
  }) async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    return LocalNotificationScheduler._(plugin, texts,
        askPermissions: askPermissions);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> _ensurePermissions() async {
    final android = _android;
    if (android == null) return false;
    if (!_permissionAsked) {
      _permissionAsked = true;
      await android.requestNotificationsPermission();
      if (await android.canScheduleExactNotifications() != true) {
        await android.requestExactAlarmsPermission();
      }
    }
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> schedule(ActiveChallenge challenge) async {
    await cancel(challenge);
    final times = upcomingReminders(challenge, DateTime.now());
    if (times.isEmpty) return;
    final exact = await _ensurePermissions();
    final l10n = await _texts();
    final texts = reminderTexts(l10n, challenge.template, plan: challenge.plan);
    final actions = switch (reminderActionsFor(challenge.template.kind)) {
      ReminderActions.journalInput => [
          AndroidNotificationAction(
            actionDone,
            texts.journalAction,
            inputs: [AndroidNotificationActionInput(label: texts.journalInput)],
          ),
        ],
      ReminderActions.none => const <AndroidNotificationAction>[],
      ReminderActions.doneMissed => [
          AndroidNotificationAction(actionDone, texts.done),
          AndroidNotificationAction(actionMissed, texts.missed),
        ],
    };

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.channelReminders,
        channelDescription: l10n.channelRemindersDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: actions,
      ),
    );
    for (final (i, time) in times.indexed) {
      await _plugin.zonedSchedule(
        id: _slotId(challenge, i),
        title: texts.title,
        body: texts.body,
        payload: challenge.id,
        scheduledDate: tz.TZDateTime(
            tz.local, time.year, time.month, time.day, time.hour, time.minute),
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  int _sessionId(ActiveChallenge c) => notificationIdFor('session:${c.id}');
  int _targetId(ActiveChallenge c) => notificationIdFor('target:${c.id}');

  @override
  Future<void> showSession(ActiveChallenge challenge) async {
    final start = challenge.sessionStartedAt;
    if (start == null) return;
    final exact = await _ensurePermissions();
    final l10n = await _texts();
    final t = challenge.template;
    final stop = AndroidNotificationAction(actionStop, '■ ${l10n.sessionStop}');
    await _plugin.show(
      id: _sessionId(challenge),
      title: '${t.emoji} ${t.titleIn(l10n)}',
      body: switch (t.targetDuration) {
        final d? => l10n.sessionRunningTarget(d.inMinutes),
        null => l10n.sessionRunning,
      },
      payload: challenge.id,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannelId,
          l10n.channelSessions,
          channelDescription: l10n.channelSessionsDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: true,
          when: start.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.stopwatch,
          actions: [stop],
        ),
      ),
    );
    final end = challenge.sessionTargetEnd;
    if (end != null && end.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _targetId(challenge),
        title: '${t.emoji} ${l10n.targetReached}',
        body: l10n.targetReachedBody,
        payload: challenge.id,
        scheduledDate: tz.TZDateTime.from(end, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.channelReminders,
            channelDescription: l10n.channelRemindersDescription,
            importance: Importance.high,
            priority: Priority.high,
            actions: [stop],
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> clearSession(ActiveChallenge challenge) async {
    await _plugin.cancel(id: _sessionId(challenge));
    await _plugin.cancel(id: _targetId(challenge));
  }

  int _slotId(ActiveChallenge c, int slot) =>
      notificationIdFor('${c.id}:r$slot');

  int _weekdayId(ActiveChallenge c, int weekday) =>
      notificationIdFor('${c.id}:wd$weekday');

  @override
  Future<void> cancel(ActiveChallenge challenge) async {
    // Alte Einzel-/Wochentags-Termine (frühere Versionen) und alle Slots.
    await _plugin.cancel(id: notificationIdFor(challenge.id));
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(id: _weekdayId(challenge, wd));
    }
    for (var i = 0; i < maxUpcomingReminders; i++) {
      await _plugin.cancel(id: _slotId(challenge, i));
    }
  }
}
