import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';
import 'domain/reminder_plan.dart';
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';

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
  static const _key = 'locale';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(_key);
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// The language actually in use (setting, else system, else Ukrainian).
Locale effectiveLocale(Locale? chosen) {
  if (chosen != null) return chosen;
  for (final l in PlatformDispatcher.instance.locales) {
    if (AppLocalizations.supportedLocales.any(
      (s) => s.languageCode == l.languageCode,
    )) {
      return Locale(l.languageCode);
    }
  }
  return const Locale('uk');
}

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

List<PlanEntry> toPlanEntries(List<PlannedSchedule> plan) => [
  for (final p in plan)
    PlanEntry(
      medicationId: p.medication.id,
      name: p.medication.name,
      unit: p.medication.unit,
      rule: p.schedule.rule,
    ),
];

/// Keeps scheduled notifications in sync with the database and language.
/// Call [resync] when the app returns to the foreground to roll the window.
class ReminderSync {
  ReminderSync(this.ref) {
    ref.listen(activePlanProvider, (_, next) {
      if (next.hasValue) _schedule();
    }, fireImmediately: true);
    ref.listen(localeProvider, (_, _) => _schedule());
  }

  final Ref ref;
  Timer? _debounce;
  int lastScheduled = 0;

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), resync);
  }

  Future<void> resync() async {
    final plan = await ref.read(databaseProvider).activePlan();
    final now = DateTime.now();
    final reminders = buildReminders(
      toPlanEntries(plan),
      from: now,
      to: now.add(NotificationService.horizon),
    );
    final l = lookupAppLocalizations(effectiveLocale(ref.read(localeProvider)));
    lastScheduled = await ref
        .read(notificationServiceProvider)
        .replaceAll(reminders, l);
  }

  void dispose() => _debounce?.cancel();
}

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
