import 'package:bady/domain/schedule_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
    DateTime(y, m, day, h, min);

List<DateTime> times(ScheduleRule r, DateTime from, DateTime to) =>
    r.occurrences(from, to).map((o) => o.at).toList();

void main() {
  const nine = DoseTime(hour: 9, minute: 0);
  const nineAm = [nine];

  group('daily', () {
    test('every day at 09:00, forever', () {
      final r = ScheduleRule(startDate: d(2026, 11, 17), times: nineAm);
      expect(times(r, d(2026, 11, 17), d(2026, 11, 20)), [
        d(2026, 11, 17, 9),
        d(2026, 11, 18, 9),
        d(2026, 11, 19, 9),
      ]);
    });

    test('nothing before the start date', () {
      final r = ScheduleRule(startDate: d(2026, 11, 20), times: nineAm);
      expect(times(r, d(2026, 11, 17), d(2026, 11, 21)), [d(2026, 11, 20, 9)]);
    });

    test('from/to bounds are [from, to)', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        times: const [
          DoseTime(hour: 8, minute: 0),
          DoseTime(hour: 20, minute: 0, dose: 2),
        ],
      );
      final list = r.occurrences(d(2026, 1, 1, 8), d(2026, 1, 1, 20));
      expect(list, [DoseOccurrence(d(2026, 1, 1, 8), 1)]);
    });

    test('times are kept sorted', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        times: const [
          DoseTime(hour: 21, minute: 0),
          DoseTime(hour: 7, minute: 30),
        ],
      );
      expect(r.times.first.hour, 7);
      expect(r.dailyAmount, 2);
    });
  });

  group('weekdays', () {
    test('Mon/Wed/Fri only', () {
      // 2026-11-16 is a Monday.
      final r = ScheduleRule(
        startDate: d(2026, 11, 16),
        dayPattern: DayPattern.weekdays,
        weekdays: const {DateTime.monday, DateTime.wednesday, DateTime.friday},
        times: nineAm,
      );
      expect(times(r, d(2026, 11, 16), d(2026, 11, 23)), [
        d(2026, 11, 16, 9),
        d(2026, 11, 18, 9),
        d(2026, 11, 20, 9),
      ]);
    });
  });

  group('every N days', () {
    test('every other day counts from the start date', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        dayPattern: DayPattern.everyNDays,
        everyNDays: 2,
        times: nineAm,
      );
      expect(times(r, d(2026, 11, 18), d(2026, 11, 24)), [
        d(2026, 11, 19, 9),
        d(2026, 11, 21, 9),
        d(2026, 11, 23, 9),
      ]);
    });
  });

  group('cycle', () {
    test('3 on, 2 off repeats', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        dayPattern: DayPattern.cycle,
        cycleOnDays: 3,
        cycleOffDays: 2,
        times: nineAm,
      );
      final days = times(
        r,
        d(2026, 1, 1),
        d(2026, 1, 11),
      ).map((t) => t.day).toList();
      expect(days, [1, 2, 3, 6, 7, 8]);
    });
  });

  group('as needed', () {
    test('never produces reminders', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        dayPattern: DayPattern.asNeeded,
      );
      expect(r.occurrences(d(2026, 1, 1), d(2026, 2, 1)), isEmpty);
      expect(r.isValid, isTrue);
    });
  });

  group('duration', () {
    test('N days includes the start day', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        durationType: DurationType.days,
        durationValue: 3,
        times: nineAm,
      );
      expect(r.lastDay, d(2026, 11, 19));
      expect(times(r, d(2026, 11, 1), d(2026, 12, 1)).length, 3);
    });

    test('until date is inclusive', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        durationType: DurationType.untilDate,
        endDate: d(2026, 11, 18),
        times: nineAm,
      );
      expect(times(r, d(2026, 11, 1), d(2026, 12, 1)), [
        d(2026, 11, 17, 9),
        d(2026, 11, 18, 9),
      ]);
    });

    test('dose count stops after N doses, across days', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        durationType: DurationType.doseCount,
        durationValue: 5,
        times: const [
          DoseTime(hour: 8, minute: 0),
          DoseTime(hour: 20, minute: 0),
        ],
      );
      expect(times(r, d(2026, 11, 1), d(2026, 12, 1)), [
        d(2026, 11, 17, 8),
        d(2026, 11, 17, 20),
        d(2026, 11, 18, 8),
        d(2026, 11, 18, 20),
        d(2026, 11, 19, 8),
      ]);
      expect(r.lastDay, d(2026, 11, 19));
    });

    test('dose count accounts for doses before the window', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        durationType: DurationType.doseCount,
        durationValue: 5,
        times: const [
          DoseTime(hour: 8, minute: 0),
          DoseTime(hour: 20, minute: 0),
        ],
      );
      expect(times(r, d(2026, 11, 18, 12), d(2026, 12, 1)), [
        d(2026, 11, 18, 20),
        d(2026, 11, 19, 8),
      ]);
    });

    test('dose count with every-other-day pattern', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        durationType: DurationType.doseCount,
        durationValue: 3,
        dayPattern: DayPattern.everyNDays,
        everyNDays: 2,
        times: nineAm,
      );
      expect(r.lastDay, d(2026, 1, 5));
      expect(times(r, d(2026, 1, 1), d(2026, 2, 1)).length, 3);
    });
  });

  group('real-world examples from the spec', () {
    test('antibiotic every 8 hours for 7 days', () {
      final r = ScheduleRule(
        startDate: d(2026, 11, 17),
        durationType: DurationType.days,
        durationValue: 7,
        times: intervalTimes(
          everyHours: 8,
          fromHour: 6,
          fromMinute: 0,
          untilHour: 23,
          untilMinute: 59,
        ),
      );
      expect(r.times.map((t) => t.hour), [6, 14, 22]);
      expect(times(r, d(2026, 11, 1), d(2026, 12, 31)).length, 21);
    });

    test('21 on / 7 off over 8 weeks gives 42 days', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        dayPattern: DayPattern.cycle,
        cycleOnDays: 21,
        cycleOffDays: 7,
        times: nineAm,
      );
      expect(times(r, d(2026, 1, 1), addDays(d(2026, 1, 1), 56)).length, 42);
    });
  });

  test('daylight saving change does not shift days', () {
    // Europe switches clocks on the last Sunday of March.
    final r = ScheduleRule(
      startDate: d(2026, 3, 27),
      dayPattern: DayPattern.everyNDays,
      everyNDays: 2,
      times: nineAm,
    );
    expect(times(r, d(2026, 3, 27), d(2026, 4, 2)).map((t) => t.day), [
      27,
      29,
      31,
    ]);
  });

  test('nextAfter finds the next dose', () {
    final r = ScheduleRule(startDate: d(2026, 11, 17), times: nineAm);
    expect(r.nextAfter(d(2026, 11, 17, 10))?.at, d(2026, 11, 18, 9));
  });

  group('validation', () {
    test('requires times unless as-needed', () {
      expect(
        ScheduleRule(startDate: d(2026, 1, 1)).validate(),
        contains(ScheduleProblem.noTimes),
      );
    });

    test('weekdays pattern needs a weekday', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 1),
        dayPattern: DayPattern.weekdays,
        times: nineAm,
      );
      expect(r.validate(), [ScheduleProblem.noWeekdays]);
    });

    test('duplicate times and bad duration', () {
      final r = ScheduleRule(
        startDate: d(2026, 1, 10),
        durationType: DurationType.untilDate,
        endDate: d(2026, 1, 1),
        times: const [nine, nine],
      );
      expect(
        r.validate(),
        containsAll([
          ScheduleProblem.duplicateTimes,
          ScheduleProblem.badDuration,
        ]),
      );
    });
  });

  test('JSON round trip', () {
    final r = ScheduleRule(
      startDate: d(2026, 11, 17),
      durationType: DurationType.untilDate,
      endDate: d(2027, 1, 31),
      dayPattern: DayPattern.weekdays,
      weekdays: const {1, 3, 5},
      times: const [
        DoseTime(hour: 8, minute: 15, dose: 0.5),
        DoseTime(hour: 21, minute: 0, dose: 2),
      ],
    );
    final back = ScheduleRule.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(
      times(back, d(2026, 11, 17), d(2026, 11, 24)),
      times(r, d(2026, 11, 17), d(2026, 11, 24)),
    );
  });

  test('intervalTimes stops before midnight', () {
    final list = intervalTimes(
      everyHours: 6,
      fromHour: 8,
      fromMinute: 30,
      untilHour: 23,
      untilMinute: 0,
    );
    expect(list.map((t) => t.toString().substring(0, 5)), [
      '08:30',
      '14:30',
      '20:30',
    ]);
  });
}
