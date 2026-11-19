import 'package:bady/domain/dose_plan.dart';
import 'package:bady/domain/enums.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:bady/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 18, 12);
  final start = DateTime(2026, 11, 14);
  DateTime nine(int day) => DateTime(2026, 11, day, 9);

  final entries = [
    PlanEntry(
      medicationId: 1,
      name: 'D',
      unit: '',
      rule: ScheduleRule(
        startDate: start,
        times: const [
          DoseTime(hour: 9, minute: 0),
          DoseTime(hour: 21, minute: 0),
        ],
      ),
    ),
  ];

  LoggedDose taken(DateTime t) => LoggedDose(
    medicationId: 1,
    scheduledAt: t,
    status: DoseStatus.taken,
    dose: 1,
  );

  test('counts only doses already due', () {
    final stats = computeStats(
      entries: entries,
      logged: [taken(nine(18))],
      now: now,
      periodDays: 1,
    );
    expect(stats.total.taken, 1);
    expect(stats.total.total, 1); // 21:00 today is not due yet
    expect(stats.total.adherence, 1);
  });

  test('missed, skipped and per-medication totals', () {
    final stats = computeStats(
      entries: entries,
      logged: [
        taken(nine(17)),
        taken(DateTime(2026, 11, 17, 21)),
        LoggedDose(
          medicationId: 1,
          scheduledAt: nine(16),
          status: DoseStatus.skipped,
          dose: 1,
        ),
      ],
      now: now,
      periodDays: 3,
    );
    // 16th: skipped + missed, 17th: 2 taken, 18th: missed 9:00.
    expect(stats.days.map((d) => d.counts.total), [2, 2, 1]);
    expect(stats.total.taken, 2);
    expect(stats.total.skipped, 1);
    expect(stats.total.missed, 2);
    expect(stats.byMedication[1]!.total, 5);
  });

  test('streak ends at the last day with a miss; unfinished today is ok', () {
    final stats = computeStats(
      entries: entries,
      logged: [
        for (final d in [16, 17]) ...[
          taken(nine(d)),
          taken(DateTime(2026, 11, d, 21)),
        ],
      ],
      now: now,
      periodDays: 7,
    );
    // 18th has a missed 9:00 but is today; 16 and 17 complete; 15 missed.
    expect(stats.streak, 2);
    expect(stats.days.length, 7);
  });

  test('no schedules means empty stats', () {
    final stats = computeStats(
      entries: const [],
      logged: const [],
      now: now,
      periodDays: 30,
    );
    expect(stats.isEmpty, isTrue);
    expect(stats.streak, 0);
  });
}
