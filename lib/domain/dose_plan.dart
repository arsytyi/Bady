/// Pure-Dart planning of doses: what is due on a day, what has been logged,
/// and which notifications to schedule. No Flutter or database imports.
library;

import 'enums.dart';
import 'look.dart';
import 'schedule_rule.dart';

/// A schedule together with the medication fields planning needs.
class PlanEntry {
  const PlanEntry({
    required this.medicationId,
    required this.name,
    required this.unit,
    required this.rule,
    this.look = const PillLook(),
    this.meal = MealRelation.any,
  });

  final int medicationId;
  final String name;
  final String unit;
  final ScheduleRule rule;
  final PillLook look;
  final MealRelation meal;
}

/// What a medication looks like, for drawing it in notifications.
class PillLook {
  const PillLook({
    this.shape = PillShape.roundTablet,
    this.color = 0xFFFFFFFF,
    this.color2,
  });

  final PillShape shape;
  final int color;
  final int? color2;

  /// Identifies the drawing, e.g. to notice when a reminder's icon changes.
  String get key => '${shape.name}:$color:$color2';
}

/// A dose that was logged (taken, skipped or snoozed).
class LoggedDose {
  const LoggedDose({
    this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    required this.dose,
    this.actualAt,
  });

  final int? id;
  final int medicationId;

  /// Null for an unscheduled ("as needed") dose.
  final DateTime? scheduledAt;
  final DoseStatus status;
  final double dose;

  /// When it was taken or skipped; for [DoseStatus.snoozed], when the
  /// snoozed reminder fires.
  final DateTime? actualAt;
}

/// What the user sees for a dose.
enum DoseState { planned, overdue, snoozed, taken, skipped }

class DoseSlot {
  const DoseSlot({
    required this.medicationId,
    required this.time,
    required this.dose,
    required this.state,
    this.scheduledAt,
    this.actualAt,
    this.eventId,
  });

  final int medicationId;

  /// Scheduled time, or the actual time for unscheduled doses.
  final DateTime time;

  /// Null for unscheduled doses.
  final DateTime? scheduledAt;
  final double dose;
  final DoseState state;
  final DateTime? actualAt;
  final int? eventId;

  bool get isPending =>
      state == DoseState.planned ||
      state == DoseState.overdue ||
      state == DoseState.snoozed;

  bool get isLogged => eventId != null && state != DoseState.snoozed;
}

typedef _Key = (int, DateTime);

DoseState _stateFor(LoggedDose? e, DateTime time, DateTime now) {
  if (e == null) {
    return time.isAfter(now) ? DoseState.planned : DoseState.overdue;
  }
  switch (e.status) {
    case DoseStatus.taken:
      return DoseState.taken;
    case DoseStatus.skipped:
      return DoseState.skipped;
    case DoseStatus.snoozed:
      final until = e.actualAt;
      return until != null && until.isAfter(now)
          ? DoseState.snoozed
          : DoseState.overdue;
    case DoseStatus.missed:
      return DoseState.overdue;
  }
}

/// All doses for [day]: scheduled ones merged with what was logged, plus
/// unscheduled doses logged that day. Sorted by time.
List<DoseSlot> buildDay({
  required Iterable<PlanEntry> entries,
  required Iterable<LoggedDose> logged,
  required DateTime day,
  required DateTime now,
}) {
  final start = dateOnly(day);
  final end = addDays(start, 1);
  final byKey = <_Key, LoggedDose>{
    for (final e in logged)
      if (e.scheduledAt != null) (e.medicationId, e.scheduledAt!): e,
  };
  final slots = <DoseSlot>[];
  final seen = <_Key>{};

  for (final entry in entries) {
    for (final o in entry.rule.occurrences(start, end)) {
      final key = (entry.medicationId, o.at);
      if (!seen.add(key)) continue;
      final e = byKey[key];
      slots.add(
        DoseSlot(
          medicationId: entry.medicationId,
          time: o.at,
          scheduledAt: o.at,
          dose: e?.dose ?? o.dose,
          state: _stateFor(e, o.at, now),
          actualAt: e?.actualAt,
          eventId: e?.id,
        ),
      );
    }
  }

  // Logged doses that no longer match a schedule (edited or deleted), and
  // unscheduled doses.
  for (final e in logged) {
    final time = e.scheduledAt ?? e.actualAt;
    if (time == null || time.isBefore(start) || !time.isBefore(end)) continue;
    if (e.scheduledAt != null &&
        seen.contains((e.medicationId, e.scheduledAt!))) {
      continue;
    }
    slots.add(
      DoseSlot(
        medicationId: e.medicationId,
        time: time,
        scheduledAt: e.scheduledAt,
        dose: e.dose,
        state: _stateFor(e, time, now),
        actualAt: e.actualAt,
        eventId: e.id,
      ),
    );
  }

  slots.sort((a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.medicationId.compareTo(b.medicationId);
  });
  return slots;
}

class DaySummary {
  const DaySummary({
    required this.total,
    required this.taken,
    required this.skipped,
    required this.pending,
  });

  final int total;
  final int taken;
  final int skipped;
  final int pending;

  double get progress => total == 0 ? 0 : taken / total;
}

DaySummary summarize(List<DoseSlot> slots) {
  var taken = 0, skipped = 0, pending = 0;
  for (final s in slots) {
    switch (s.state) {
      case DoseState.taken:
        taken++;
      case DoseState.skipped:
        skipped++;
      default:
        pending++;
    }
  }
  return DaySummary(
    total: slots.length,
    taken: taken,
    skipped: skipped,
    pending: pending,
  );
}

/// Part of the day a dose time falls into.
enum DayPart { night, morning, afternoon, evening }

DayPart dayPartOf(DateTime t) => switch (t.hour) {
  < 4 => DayPart.night,
  < 12 => DayPart.morning,
  < 17 => DayPart.afternoon,
  _ => DayPart.evening,
};

// ---------------------------------------------------------------------------
// Notifications

enum NotificationKind { main, followUp, snooze }

class NotificationItem {
  const NotificationItem({
    required this.medicationId,
    required this.name,
    required this.dose,
    required this.unit,
    this.look = const PillLook(),
    this.meal = MealRelation.any,
  });

  final int medicationId;
  final String name;
  final double dose;
  final String unit;
  final PillLook look;

  /// Shown in the reminder ("after meals").
  final MealRelation meal;
}

/// One notification to schedule. [doseTime] identifies the doses it is
/// about; [at] is when it fires.
class PlannedNotification {
  PlannedNotification({
    required this.doseTime,
    required this.at,
    required this.kind,
    required this.items,
    int followUpIndex = 0,
  }) : id = notificationIdFor(doseTime, switch (kind) {
         NotificationKind.main => 0,
         NotificationKind.followUp => 1 + followUpIndex.clamp(0, 1),
         NotificationKind.snooze => 3,
       });

  final int id;
  final DateTime doseTime;
  final DateTime at;
  final NotificationKind kind;
  final List<NotificationItem> items;
}

/// Four notification ids per dose minute: main, two follow-ups, snooze.
int notificationIdFor(DateTime doseTime, int slot) {
  final minute =
      doseTime.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
  return (minute % 0x1FFFFFFF) * 4 + slot;
}

List<int> allNotificationIdsFor(DateTime doseTime) => [
  for (var k = 0; k < 4; k++) notificationIdFor(doseTime, k),
];

/// Works out every notification to schedule from [now] to [now] + [horizon]:
/// the main reminder, follow-ups for doses still not logged, and snoozed
/// reminders. Doses already taken or skipped get nothing.
List<PlannedNotification> buildNotificationPlan({
  required Iterable<PlanEntry> entries,
  required Iterable<LoggedDose> logged,
  required DateTime now,
  Duration horizon = const Duration(days: 14),
  List<int> followUpMinutes = const [15, 30],
  int maxCount = 400,
}) {
  final maxFollow = followUpMinutes.isEmpty
      ? 0
      : followUpMinutes.reduce((a, b) => a > b ? a : b);
  final from = now.subtract(Duration(minutes: maxFollow));
  final to = now.add(horizon);
  final byKey = <_Key, LoggedDose>{
    for (final e in logged)
      if (e.scheduledAt != null) (e.medicationId, e.scheduledAt!): e,
  };

  // (fire time, kind, follow-up index, dose time) -> items
  final groups =
      <(DateTime, NotificationKind, int, DateTime), List<NotificationItem>>{};
  void add(
    DateTime at,
    NotificationKind kind,
    int index,
    DateTime doseTime,
    NotificationItem item,
  ) {
    if (!at.isAfter(now)) return;
    groups.putIfAbsent((at, kind, index, doseTime), () => []).add(item);
  }

  for (final entry in entries) {
    for (final o in entry.rule.occurrences(from, to)) {
      final item = NotificationItem(
        medicationId: entry.medicationId,
        name: entry.name,
        dose: o.dose,
        unit: entry.unit,
        look: entry.look,
        meal: entry.meal,
      );
      final e = byKey[(entry.medicationId, o.at)];
      if (e != null &&
          (e.status == DoseStatus.taken || e.status == DoseStatus.skipped)) {
        continue;
      }
      if (e != null &&
          e.status == DoseStatus.snoozed &&
          e.actualAt != null &&
          e.actualAt!.isAfter(now)) {
        add(e.actualAt!, NotificationKind.snooze, 0, o.at, item);
        continue;
      }
      add(o.at, NotificationKind.main, 0, o.at, item);
      for (final (i, m) in followUpMinutes.take(2).indexed) {
        add(
          o.at.add(Duration(minutes: m)),
          NotificationKind.followUp,
          i,
          o.at,
          item,
        );
      }
    }
  }

  final keys = groups.keys.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final k in keys.take(maxCount))
      PlannedNotification(
        doseTime: k.$4,
        at: k.$1,
        kind: k.$2,
        followUpIndex: k.$3,
        items: groups[k]!..sort((a, b) => a.name.compareTo(b.name)),
      ),
  ];
}
