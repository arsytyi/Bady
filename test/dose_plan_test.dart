import 'package:bady/domain/dose_plan.dart';
import 'package:bady/domain/enums.dart';
import 'package:bady/domain/notification_payload.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 18);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 18, h, m);

  PlanEntry entry(int id, String name, List<DoseTime> times) => PlanEntry(
    medicationId: id,
    name: name,
    unit: 'табл.',
    rule: ScheduleRule(startDate: day, times: times),
  );

  final vitD = entry(1, 'Вітамін D', const [DoseTime(hour: 9, minute: 0)]);
  final mag = entry(2, 'Магній', const [
    DoseTime(hour: 9, minute: 0),
    DoseTime(hour: 21, minute: 0, dose: 2),
  ]);

  group('buildDay', () {
    test('states depend on time and log', () {
      final slots = buildDay(
        entries: [vitD, mag],
        logged: [
          LoggedDose(
            id: 1,
            medicationId: 1,
            scheduledAt: at(9),
            status: DoseStatus.taken,
            dose: 1,
            actualAt: at(9, 12),
          ),
        ],
        day: day,
        now: at(12),
      );
      expect(slots.map((s) => (s.medicationId, s.time.hour, s.state)), [
        (1, 9, DoseState.taken),
        (2, 9, DoseState.overdue),
        (2, 21, DoseState.planned),
      ]);
      final summary = summarize(slots);
      expect(summary.taken, 1);
      expect(summary.pending, 2);
      expect(summary.progress, closeTo(1 / 3, 1e-9));
    });

    test('snoozed until later is snoozed, until earlier is overdue', () {
      LoggedDose snoozed(DateTime until) => LoggedDose(
        medicationId: 1,
        scheduledAt: at(9),
        status: DoseStatus.snoozed,
        dose: 1,
        actualAt: until,
      );
      expect(
        buildDay(
          entries: [vitD],
          logged: [snoozed(at(9, 10))],
          day: day,
          now: at(9, 5),
        ).single.state,
        DoseState.snoozed,
      );
      expect(
        buildDay(
          entries: [vitD],
          logged: [snoozed(at(9, 10))],
          day: day,
          now: at(9, 20),
        ).single.state,
        DoseState.overdue,
      );
    });

    test('keeps logged doses whose schedule changed and unscheduled ones', () {
      final slots = buildDay(
        entries: const [],
        logged: [
          LoggedDose(
            id: 5,
            medicationId: 3,
            scheduledAt: at(8),
            status: DoseStatus.skipped,
            dose: 1,
            actualAt: at(8, 30),
          ),
          LoggedDose(
            id: 6,
            medicationId: 4,
            scheduledAt: null,
            status: DoseStatus.taken,
            dose: 1,
            actualAt: at(14),
          ),
        ],
        day: day,
        now: at(20),
      );
      expect(slots.map((s) => (s.medicationId, s.state)), [
        (3, DoseState.skipped),
        (4, DoseState.taken),
      ]);
      expect(slots.last.scheduledAt, isNull);
    });

    test('day parts', () {
      expect(dayPartOf(at(2)), DayPart.night);
      expect(dayPartOf(at(8)), DayPart.morning);
      expect(dayPartOf(at(13)), DayPart.afternoon);
      expect(dayPartOf(at(22)), DayPart.evening);
    });
  });

  group('buildNotificationPlan', () {
    test('groups by minute with follow-ups for pending doses', () {
      final plan = buildNotificationPlan(
        entries: [vitD, mag],
        logged: const [],
        now: at(8),
        horizon: const Duration(hours: 14),
      );
      final nine = plan.where((n) => n.doseTime == at(9)).toList();
      expect(nine.map((n) => (n.kind, n.at)), [
        (NotificationKind.main, at(9)),
        (NotificationKind.followUp, at(9, 15)),
        (NotificationKind.followUp, at(9, 30)),
      ]);
      expect(nine.first.items.map((i) => i.name), ['Вітамін D', 'Магній']);
      expect(plan.map((n) => n.id).toSet().length, plan.length);
    });

    test('taken or skipped doses get no notifications', () {
      final plan = buildNotificationPlan(
        entries: [vitD, mag],
        logged: [
          LoggedDose(
            medicationId: 1,
            scheduledAt: at(9),
            status: DoseStatus.taken,
            dose: 1,
          ),
        ],
        now: at(8),
        horizon: const Duration(hours: 2),
      );
      expect(plan.expand((n) => n.items).map((i) => i.medicationId).toSet(), {
        2,
      });
    });

    test('a snoozed dose gets a snooze notification instead', () {
      final plan = buildNotificationPlan(
        entries: [vitD],
        logged: [
          LoggedDose(
            medicationId: 1,
            scheduledAt: at(9),
            status: DoseStatus.snoozed,
            dose: 1,
            actualAt: at(9, 10),
          ),
        ],
        now: at(9, 1),
        horizon: const Duration(hours: 1),
      );
      expect(plan.single.kind, NotificationKind.snooze);
      expect(plan.single.at, at(9, 10));
      expect(plan.single.id, notificationIdFor(at(9), 3));
    });

    test('follow-ups still scheduled for a dose just missed', () {
      final plan = buildNotificationPlan(
        entries: [vitD],
        logged: const [],
        now: at(9, 5),
        horizon: const Duration(hours: 1),
      );
      expect(plan.map((n) => n.at), [at(9, 15), at(9, 30)]);
    });

    test('no follow-ups when repeating is off', () {
      final plan = buildNotificationPlan(
        entries: [vitD],
        logged: const [],
        now: at(8),
        horizon: const Duration(hours: 2),
        followUpMinutes: const [],
      );
      expect(plan.single.kind, NotificationKind.main);
    });
  });

  test('payload round trip', () {
    final p = NotificationPayload(doseTime: at(9), doses: {1: 1, 2: 0.5});
    final back = NotificationPayload.tryDecode(p.encode())!;
    expect(back.doseTime, at(9));
    expect(back.doses, {1: 1.0, 2: 0.5});
    expect(NotificationPayload.tryDecode('nonsense'), isNull);
  });
}
