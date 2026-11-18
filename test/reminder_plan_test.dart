import 'package:bady/domain/format.dart';
import 'package:bady/domain/reminder_plan.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 17);

  PlanEntry entry(int id, String name, List<DoseTime> times) => PlanEntry(
    medicationId: id,
    name: name,
    unit: 'табл.',
    rule: ScheduleRule(startDate: start, times: times),
  );

  test('doses at the same minute are grouped into one reminder', () {
    final reminders = buildReminders(
      [
        entry(1, 'Магній', const [DoseTime(hour: 21, minute: 0, dose: 2)]),
        entry(2, 'Вітамін D', const [
          DoseTime(hour: 9, minute: 0),
          DoseTime(hour: 21, minute: 0),
        ]),
      ],
      from: start,
      to: start.add(const Duration(days: 1)),
    );
    expect(reminders.map((r) => r.at.hour), [9, 21]);
    expect(reminders[1].items.map((i) => i.name), ['Вітамін D', 'Магній']);
    expect(reminders[1].items.last.dose, 2);
  });

  test('ids are unique per minute and limited by maxCount', () {
    final reminders = buildReminders(
      [
        entry(1, 'A', const [
          DoseTime(hour: 8, minute: 0),
          DoseTime(hour: 8, minute: 1),
        ]),
      ],
      from: start,
      to: start.add(const Duration(days: 30)),
      maxCount: 10,
    );
    expect(reminders.length, 10);
    expect(reminders.map((r) => r.notificationId).toSet().length, 10);
  });

  test('formatDose', () {
    expect(formatDose(1), '1');
    expect(formatDose(0.5), '0.5');
    expect(formatDose(1.25), '1.25');
    expect(formatDoseWithUnit(2, 'табл.'), '2 табл.');
    expect(formatDoseWithUnit(2, ' '), '2');
  });
}
