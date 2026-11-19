import 'package:bady/domain/schedule_rule.dart';
import 'package:bady/domain/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 18, 12);
  // Two tablets a day: 9:00 and 21:00.
  final twiceDaily = ScheduleRule(
    startDate: DateTime(2026, 11, 1),
    times: const [DoseTime(hour: 9, minute: 0), DoseTime(hour: 21, minute: 0)],
  );

  test('days left counts from the next planned dose', () {
    // 21:00 today, then 2 per day: 5 tablets cover today + 2 days.
    final f = forecastStock(stock: 5, rules: [twiceDaily], now: now);
    expect(f.daysLeft, 3); // runs short at 21:00 on the 21st
    expect(f.runsOutOn(now), DateTime(2026, 11, 21));
    expect(f.isLow, isTrue);
  });

  test('plenty of stock is not low', () {
    final f = forecastStock(stock: 60, rules: [twiceDaily], now: now);
    expect(f.daysLeft, 30);
    expect(f.isLow, isFalse);
  });

  test('no schedule means no forecast, but empty stock is low', () {
    expect(
      forecastStock(stock: 10, rules: const [], now: now).daysLeft,
      isNull,
    );
    final empty = forecastStock(stock: 0, rules: const [], now: now);
    expect(empty.daysLeft, 0);
    expect(empty.isLow, isTrue);
  });

  test('a dose-count course stops using stock when it ends', () {
    final course = ScheduleRule(
      startDate: DateTime(2026, 11, 18),
      durationType: DurationType.doseCount,
      durationValue: 3,
      times: const [DoseTime(hour: 20, minute: 0)],
    );
    expect(forecastStock(stock: 3, rules: [course], now: now).daysLeft, isNull);
  });

  test('low-stock reminders start on the day stock gets low', () {
    final plan = planLowStockReminders(
      items: [
        StockItem(
          medicationId: 1,
          stock: 30,
          lowStockDays: 7,
          rules: [twiceDaily],
        ),
      ],
      now: now,
      days: 14,
    );
    // 30 tablets at 2/day: at 10:00 on day N the forecast drops to 7 days.
    final first = plan.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    expect(first, DateTime(2026, 11, 26, 10));
    expect(plan[first], [1]);
    expect(plan.keys.every((d) => d.hour == 10), isTrue);
    // Today's 10:00 is already past.
    expect(plan.containsKey(DateTime(2026, 11, 18, 10)), isFalse);
  });
}
