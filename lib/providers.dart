import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';
import 'domain/dose_plan.dart';
import 'domain/schedule_rule.dart';
import 'services/dose_actions.dart';
import 'services/notification_service.dart';
import 'services/settings.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The language picked in settings; null follows the system.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => Prefs.chosenLocale(ref.read(sharedPreferencesProvider));

  Future<void> set(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(Prefs.locale);
    } else {
      await prefs.setString(Prefs.locale, locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// Reminder behaviour from settings.
class ReminderSettings {
  const ReminderSettings({required this.snoozeMinutes, required this.repeat});

  final int snoozeMinutes;
  final bool repeat;
}

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final p = ref.read(sharedPreferencesProvider);
    return ReminderSettings(
      snoozeMinutes: Prefs.snooze(p),
      repeat: Prefs.repeat(p),
    );
  }

  Future<void> setSnooze(int minutes) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(Prefs.snoozeMinutes, minutes);
    state = ReminderSettings(snoozeMinutes: minutes, repeat: state.repeat);
  }

  Future<void> setRepeat(bool repeat) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(Prefs.repeatReminders, repeat);
    state = ReminderSettings(
      snoozeMinutes: state.snoozeMinutes,
      repeat: repeat,
    );
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

final medicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(databaseProvider).watchMedications(),
);

final archivedMedicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(databaseProvider).watchMedications(archived: true),
);

final medicationProvider = StreamProvider.family<Medication?, int>(
  (ref, id) => ref.watch(databaseProvider).watchMedication(id),
);

final schedulesProvider = StreamProvider.family<List<Schedule>, int>(
  (ref, id) => ref.watch(databaseProvider).watchSchedulesFor(id),
);

final activePlanProvider = StreamProvider<List<PlannedSchedule>>(
  (ref) => ref.watch(databaseProvider).watchActivePlan(),
);

/// Logged doses for one calendar day.
final dayEventsProvider = StreamProvider.family<List<DoseEvent>, DateTime>((
  ref,
  day,
) {
  final start = dateOnly(day);
  final end = addDays(start, 1).subtract(const Duration(microseconds: 1));
  return ref.watch(databaseProvider).watchEventsBetween(start, end);
});

/// Every medication, including archived ones, by id (for showing history).
final allMedicationsProvider = StreamProvider<Map<int, Medication>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .select(db.medications)
      .watch()
      .map((list) => {for (final m in list) m.id: m});
});

List<PlanEntry> toPlanEntries(List<PlannedSchedule> plan) => [
  for (final p in plan)
    PlanEntry(
      medicationId: p.medication.id,
      name: p.medication.name,
      unit: p.medication.unit,
      rule: p.schedule.rule,
      look: p.medication.look,
    ),
];

final doseActionsProvider = Provider<DoseActions>(
  (ref) => DoseActions(
    db: ref.watch(databaseProvider),
    notifications: ref.watch(notificationServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

/// A request to show a dose, e.g. after tapping its notification.
class FocusRequest {
  FocusRequest(this.doseTime);

  final DateTime doseTime;
}

class FocusNotifier extends Notifier<FocusRequest?> {
  @override
  FocusRequest? build() => null;

  void request(DateTime doseTime) => state = FocusRequest(doseTime);

  void clear() => state = null;
}

final focusRequestProvider = NotifierProvider<FocusNotifier, FocusRequest?>(
  FocusNotifier.new,
);

/// Keeps scheduled notifications in sync with the database and settings.
/// Call [resync] after logging doses and when the app returns to the
/// foreground to roll the window forward.
class ReminderSync {
  ReminderSync(this.ref) {
    ref.listen(activePlanProvider, (_, next) {
      if (next.hasValue) schedule();
    }, fireImmediately: true);
    ref.listen(localeProvider, (_, _) => schedule());
    ref.listen(reminderSettingsProvider, (_, _) => schedule());
  }

  final Ref ref;
  Timer? _debounce;
  int lastScheduled = 0;

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), resync);
  }

  Future<void> resync() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final plan = await db.activePlan();
    final events = await db.eventsBetween(
      now.subtract(const Duration(days: 1)),
      now.add(NotificationService.horizon),
    );
    final settings = ref.read(reminderSettingsProvider);
    final notifications = buildNotificationPlan(
      entries: toPlanEntries(plan),
      logged: events.map((e) => e.toLogged()),
      now: now,
      horizon: NotificationService.horizon,
      followUpMinutes: settings.repeat ? Prefs.followUpMinutes : const [],
    );
    lastScheduled = await ref
        .read(notificationServiceProvider)
        .replaceAll(
          notifications,
          localizationsFor(ref.read(sharedPreferencesProvider)),
        );
  }

  void dispose() => _debounce?.cancel();
}

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
