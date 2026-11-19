/// Adherence statistics computed from schedules and the dose log.
library;

import 'dose_plan.dart';
import 'schedule_rule.dart';

class DoseCounts {
  const DoseCounts({this.taken = 0, this.skipped = 0, this.missed = 0});

  final int taken;
  final int skipped;

  /// Due doses never marked (or snoozed and forgotten).
  final int missed;

  int get total => taken + skipped + missed;

  /// Share of due doses that were taken, 0..1; null when nothing was due.
  double? get adherence => total == 0 ? null : taken / total;

  DoseCounts operator +(DoseCounts o) => DoseCounts(
    taken: taken + o.taken,
    skipped: skipped + o.skipped,
    missed: missed + o.missed,
  );
}

class DayStat {
  const DayStat(this.day, this.counts);

  final DateTime day;
  final DoseCounts counts;
}

class Stats {
  const Stats({
    required this.days,
    required this.total,
    required this.byMedication,
    required this.streak,
  });

  /// Oldest first.
  final List<DayStat> days;
  final DoseCounts total;
  final Map<int, DoseCounts> byMedication;

  /// Days in a row, ending today or yesterday, with every due dose taken.
  final int streak;

  bool get isEmpty => total.total == 0;
}

DoseCounts _countSlot(DoseSlot s, DateTime now) {
  // Only doses already due count.
  if (s.time.isAfter(now)) return const DoseCounts();
  return switch (s.state) {
    DoseState.taken => const DoseCounts(taken: 1),
    DoseState.skipped => const DoseCounts(skipped: 1),
    DoseState.overdue => const DoseCounts(missed: 1),
    DoseState.snoozed || DoseState.planned => const DoseCounts(),
  };
}

/// Statistics for the [periodDays] days ending today.
Stats computeStats({
  required List<PlanEntry> entries,
  required List<LoggedDose> logged,
  required DateTime now,
  required int periodDays,
  int streakLookbackDays = 366,
}) {
  final today = dateOnly(now);
  final byDay = <DateTime, List<LoggedDose>>{};
  for (final e in logged) {
    final t = e.scheduledAt ?? e.actualAt;
    if (t == null) continue;
    byDay.putIfAbsent(dateOnly(t), () => []).add(e);
  }

  DoseCounts countDay(DateTime day, [Map<int, DoseCounts>? perMed]) {
    var c = const DoseCounts();
    for (final s in buildDay(
      entries: entries,
      logged: byDay[day] ?? const [],
      day: day,
      now: now,
    )) {
      final sc = _countSlot(s, now);
      c = c + sc;
      if (perMed != null && sc.total > 0) {
        perMed[s.medicationId] =
            (perMed[s.medicationId] ?? const DoseCounts()) + sc;
      }
    }
    return c;
  }

  final perMed = <int, DoseCounts>{};
  final days = <DayStat>[];
  var total = const DoseCounts();
  for (var i = periodDays - 1; i >= 0; i--) {
    final day = addDays(today, -i);
    final c = countDay(day, perMed);
    days.add(DayStat(day, c));
    total = total + c;
  }

  // Streak: today counts only once everything due today is taken; an
  // unfinished today does not break the streak.
  var streak = 0;
  for (var i = 0; i < streakLookbackDays; i++) {
    final day = addDays(today, -i);
    final c = i < periodDays ? days[periodDays - 1 - i].counts : countDay(day);
    if (c.total == 0) continue;
    if (c.skipped + c.missed > 0) {
      if (i == 0) continue;
      break;
    }
    streak++;
  }

  return Stats(days: days, total: total, byMedication: perMed, streak: streak);
}
