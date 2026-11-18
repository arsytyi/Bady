import 'schedule_rule.dart';

/// One medication's dose inside a reminder.
class ReminderItem {
  const ReminderItem({
    required this.medicationId,
    required this.name,
    required this.dose,
    required this.unit,
  });

  final int medicationId;
  final String name;
  final double dose;
  final String unit;
}

/// All doses due at the same minute, shown as a single notification.
class Reminder {
  Reminder(this.at, this.items);

  final DateTime at;
  final List<ReminderItem> items;

  /// Stable notification id derived from the time (minutes since epoch fit
  /// comfortably in 31 bits until the year 6000).
  int get notificationId =>
      at.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute % 0x7fffffff;
}

/// Input for [buildReminders]: a schedule and the medication it belongs to.
class PlanEntry {
  const PlanEntry({
    required this.medicationId,
    required this.name,
    required this.unit,
    required this.rule,
  });

  final int medicationId;
  final String name;
  final String unit;
  final ScheduleRule rule;
}

/// Expands schedules into reminders grouped by minute, sorted by time,
/// limited to [maxCount] so we stay well below Android's alarm limit.
List<Reminder> buildReminders(
  Iterable<PlanEntry> entries, {
  required DateTime from,
  required DateTime to,
  int maxCount = 300,
}) {
  final byTime = <DateTime, List<ReminderItem>>{};
  for (final e in entries) {
    for (final o in e.rule.occurrences(from, to)) {
      byTime
          .putIfAbsent(o.at, () => [])
          .add(
            ReminderItem(
              medicationId: e.medicationId,
              name: e.name,
              dose: o.dose,
              unit: e.unit,
            ),
          );
    }
  }
  final keys = byTime.keys.toList()..sort();
  return [
    for (final k in keys.take(maxCount))
      Reminder(k, byTime[k]!..sort((a, b) => a.name.compareTo(b.name))),
  ];
}
