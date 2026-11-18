import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/dose_plan.dart';
import '../domain/format.dart';
import '../domain/notification_payload.dart';
import '../l10n/app_localizations.dart';

bool _tzReady = false;

/// Loads time-zone data and the device zone. Safe to call from any isolate.
Future<void> initTimeZones() async {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    debugPrint('Timezone lookup failed, using UTC: $e');
  }
  _tzReady = true;
}

/// Schedules local reminders with Android exact alarms. Each reminder has
/// Taken / Snooze / Skip buttons that work without opening the app.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const horizon = Duration(days: 14);
  static const _channelId = 'dose_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Call once in the main isolate. [onResponse] handles taps and actions
  /// while the app is running; [onBackgroundResponse] must be a top-level
  /// function annotated with `@pragma('vm:entry-point')`.
  Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    if (_ready || !supported) return;
    await initTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    _ready = true;
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    if (!supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final response = details!.notificationResponse;
    // A button press is handled in the background; only a tap opens a dose.
    if (response?.actionId != null) return null;
    return response?.payload;
  }

  Future<bool> requestPermissions() async {
    if (!supported) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> canScheduleExact() async {
    if (!supported) return false;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarms() async {
    if (!supported) return;
    await _android?.requestExactAlarmsPermission();
  }

  NotificationDetails _details(AppLocalizations l, {bool actions = true}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l.notifChannelName,
          channelDescription: l.notifChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          styleInformation: const DefaultStyleInformation(true, true),
          actions: actions
              ? [
                  AndroidNotificationAction(
                    NotificationActions.taken,
                    l.actionTaken,
                  ),
                  AndroidNotificationAction(
                    NotificationActions.snooze,
                    l.actionSnooze,
                  ),
                  AndroidNotificationAction(
                    NotificationActions.skip,
                    l.actionSkip,
                  ),
                ]
              : null,
        ),
      );

  String _body(PlannedNotification n) => n.items
      .map((i) => '${i.name}: ${formatDoseWithUnit(i.dose, i.unit)}')
      .join('\n');

  String _title(PlannedNotification n, AppLocalizations l) {
    final time = formatTime(n.doseTime.hour, n.doseTime.minute);
    return switch (n.kind) {
      NotificationKind.main => '${l.notifTitle} · $time',
      NotificationKind.followUp => '${l.notifTitleRepeat} · $time',
      NotificationKind.snooze => '${l.notifTitleSnoozed} · $time',
    };
  }

  static String payloadFor(PlannedNotification n) => NotificationPayload(
    doseTime: n.doseTime,
    doses: {for (final i in n.items) i.medicationId: i.dose},
  ).encode();

  Future<void> schedule(
    PlannedNotification n,
    AppLocalizations l, {
    AndroidScheduleMode? mode,
  }) async {
    await _plugin.zonedSchedule(
      id: n.id,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: _details(l),
      androidScheduleMode:
          mode ??
          (await canScheduleExact()
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle),
      title: _title(n, l),
      body: _body(n),
      payload: payloadFor(n),
    );
  }

  /// Replaces all pending reminders. Returns how many were scheduled.
  Future<int> replaceAll(
    List<PlannedNotification> plan,
    AppLocalizations l,
  ) async {
    if (!supported) return 0;
    await _plugin.cancelAllPendingNotifications();
    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();
    var count = 0;
    for (final n in plan) {
      if (!n.at.isAfter(now)) continue;
      await schedule(n, l, mode: mode);
      count++;
    }
    return count;
  }

  /// Removes shown and pending notifications for doses at [doseTime].
  Future<void> cancelForDose(DateTime doseTime) async {
    if (!supported) return;
    for (final id in allNotificationIdsFor(doseTime)) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> showTest(AppLocalizations l) async {
    if (!supported) return;
    await _plugin.show(
      id: 0,
      title: l.notifTitle,
      body: l.testNotificationBody,
      notificationDetails: _details(l, actions: false),
    );
  }

  Future<int> pendingCount() async {
    if (!supported) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
