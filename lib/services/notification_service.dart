import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/format.dart';
import '../domain/reminder_plan.dart';
import '../l10n/app_localizations.dart';

/// Schedules local reminders with Android exact alarms. Reminders are
/// recomputed from the database whenever the plan changes or the app comes
/// to the foreground, covering the next [horizon].
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const horizon = Duration(days: 14);
  static const _channelId = 'dose_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    if (!_supported) return false;
    await init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> canScheduleExact() async {
    if (!_supported) return false;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarms() async {
    if (!_supported) return;
    await _android?.requestExactAlarmsPermission();
  }

  NotificationDetails _details(AppLocalizations l) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      l.notifChannelName,
      channelDescription: l.notifChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: const DefaultStyleInformation(true, true),
    ),
  );

  String _body(Reminder r) => r.items
      .map((i) => '${i.name}: ${formatDoseWithUnit(i.dose, i.unit)}')
      .join('\n');

  /// Replaces all pending reminders with [reminders]. Returns how many were
  /// scheduled.
  Future<int> replaceAll(List<Reminder> reminders, AppLocalizations l) async {
    if (!_supported) return 0;
    await init();
    await _plugin.cancelAllPendingNotifications();
    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = _details(l);
    final now = DateTime.now();
    var count = 0;
    for (final r in reminders) {
      if (!r.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: r.notificationId,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: details,
        androidScheduleMode: mode,
        title: l.notifTitle,
        body: _body(r),
      );
      count++;
    }
    return count;
  }

  Future<void> showTest(AppLocalizations l) async {
    if (!_supported) return;
    await init();
    await _plugin.show(
      id: 0,
      title: l.notifTitle,
      body: l.testNotificationBody,
      notificationDetails: _details(l),
    );
  }

  Future<int> pendingCount() async {
    if (!_supported) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
