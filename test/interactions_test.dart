import 'dart:convert';
import 'dart:io';

import 'package:bady/domain/interactions.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = InteractionCatalog.fromJson(
    jsonDecode(File('assets/interactions.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  ScheduleRule at(int hour, [int minute = 0]) => ScheduleRule(
    startDate: DateTime(2026, 11, 1),
    times: [DoseTime(hour: hour, minute: minute)],
  );

  InteractionMed med(int id, String name, Set<String> s, List<int> hours) =>
      InteractionMed(
        id: id,
        name: name,
        substances: s,
        rules: [for (final h in hours) at(h)],
      );

  test('every rule names known substances and has a source', () {
    final keys = {for (final s in catalog.substances) s.key};
    for (final r in catalog.rules) {
      expect(keys, containsAll([r.a, r.b]));
      expect(r.source, isNotEmpty);
      if (r.type == RuleType.separate) expect(r.hours, greaterThan(0));
    }
  });

  test('detects substances from names', () {
    expect(catalog.detect('Магній B6'), {'magnesium'});
    expect(catalog.detect('Кальцій D3 Нікомед'), {'calcium', 'vitamin_d'});
    expect(catalog.detect('Вітамін D3 2000 МО'), {'vitamin_d'});
    expect(catalog.detect('Сорбіфер Дурулес'), {'iron'});
    expect(catalog.detect('Omega-3'), {'omega3'});
    // Short aliases need a whole word: "Fe" is not inside "Coffee".
    expect(catalog.detect('Coffee'), isEmpty);
    expect(catalog.detect('Еутирокс 50'), {'levothyroxine'});
  });

  test('iron and calcium too close in time are flagged with a fix', () {
    final iron = med(1, 'Залізо', {'iron'}, [9]);
    final calcium = med(2, 'Кальцій', {'calcium'}, [10]);
    final issues = findInteractions(catalog, [iron, calcium]);
    expect(issues, hasLength(1));
    final i = issues.single;
    expect(i.isWarning, isTrue);
    expect(i.rule.hours, 2);
    expect(i.suggestionFor(2), const DoseTime(hour: 11, minute: 0));
    expect(i.suggestionFor(1), const DoseTime(hour: 8, minute: 0));
  });

  test('far enough apart is fine', () {
    final issues = findInteractions(catalog, [
      med(1, 'Залізо', {'iron'}, [9]),
      med(2, 'Кальцій', {'calcium'}, [21]),
    ]);
    expect(issues, isEmpty);
  });

  test('gaps wrap around midnight', () {
    final issues = findInteractions(catalog, [
      med(1, 'Залізо', {'iron'}, [23]),
      med(2, 'Кальцій', {'calcium'}, [0]),
    ]);
    expect(issues, hasLength(1));
  });

  test('avoid rules apply regardless of time; good pairs are tips', () {
    final issues = findInteractions(catalog, [
      med(1, 'Варфарин', {'warfarin'}, [8]),
      med(2, 'K2', {'vitamin_k', 'vitamin_d'}, [20]),
      med(3, 'Кальцій', {'calcium'}, [13]),
    ]);
    final types = {for (final i in issues) i.rule.type};
    expect(types, {RuleType.avoid, RuleType.together});
    expect(issues.where((i) => i.isWarning), hasLength(1));
  });
}
