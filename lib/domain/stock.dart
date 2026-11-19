/// Stock forecasts: how long the supply lasts and when to buy more.
library;

import 'schedule_rule.dart';

class StockForecast {
  const StockForecast({
    required this.stock,
    required this.daysLeft,
    required this.lowStockDays,
  });

  final double stock;

  /// Whole days the stock covers, counting today; null when scheduled doses
  /// never use it up within the look-ahead (or nothing is scheduled).
  final int? daysLeft;
  final int lowStockDays;

  bool get isEmpty => stock <= 0;

  bool get isLow => isEmpty || (daysLeft != null && daysLeft! <= lowStockDays);

  /// The day the last covered dose falls on, or null.
  DateTime? runsOutOn(DateTime now) =>
      daysLeft == null ? null : addDays(dateOnly(now), daysLeft!);
}

/// Planned doses from [from] (inclusive) to [to] (exclusive), oldest first.
List<DoseOccurrence> _upcoming(
  Iterable<ScheduleRule> rules,
  DateTime from,
  DateTime to,
) {
  final list = [for (final r in rules) ...r.occurrences(from, to)]
    ..sort((a, b) => a.at.compareTo(b.at));
  return list;
}

/// Forecast for [stock] units consumed by [rules] from [now] on. Doses up to
/// [now] are assumed already logged (taken doses reduce the stock).
StockForecast forecastStock({
  required double stock,
  required Iterable<ScheduleRule> rules,
  required DateTime now,
  int lowStockDays = 7,
  int lookAheadDays = 366,
}) {
  int? daysLeft;
  if (stock <= 0) {
    daysLeft = 0;
  } else {
    var left = stock;
    for (final o in _upcoming(
      rules,
      now,
      now.add(Duration(days: lookAheadDays)),
    )) {
      left -= o.dose;
      // A dose that can't be fully covered is the day the stock runs out.
      if (left < -1e-9) {
        daysLeft = daysBetween(dateOnly(now), dateOnly(o.at));
        break;
      }
    }
  }
  return StockForecast(
    stock: stock,
    daysLeft: daysLeft,
    lowStockDays: lowStockDays,
  );
}

/// What a low-stock reminder is about.
class StockItem {
  const StockItem({
    required this.medicationId,
    required this.stock,
    required this.lowStockDays,
    required this.rules,
  });

  final int medicationId;
  final double stock;
  final int lowStockDays;
  final List<ScheduleRule> rules;
}

/// One low-stock reminder per day at [hour]:00 for the next [days] days,
/// listing medications whose projected stock (assuming every planned dose
/// until then is taken) is low by that time. Returns day -> medication ids.
Map<DateTime, List<int>> planLowStockReminders({
  required Iterable<StockItem> items,
  required DateTime now,
  int days = 14,
  int hour = 10,
}) {
  final result = <DateTime, List<int>>{};
  for (var i = 0; i < days; i++) {
    final day = addDays(dateOnly(now), i);
    final at = day.add(Duration(hours: hour));
    if (!at.isAfter(now)) continue;
    for (final item in items) {
      if (item.rules.isEmpty) continue;
      final used = _upcoming(
        item.rules,
        now,
        at,
      ).fold<double>(0, (sum, o) => sum + o.dose);
      final f = forecastStock(
        stock: item.stock - used,
        rules: item.rules,
        now: at,
        lowStockDays: item.lowStockDays,
      );
      if (f.isLow) result.putIfAbsent(at, () => []).add(item.medicationId);
    }
  }
  return result;
}
