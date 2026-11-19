/// Supplement and medicine compatibility, from assets/interactions.json.
library;

import 'schedule_rule.dart';

enum RuleType { avoid, separate, together }

class Substance {
  const Substance({
    required this.key,
    required this.uk,
    required this.en,
    this.aliases = const [],
  });

  final String key;
  final String uk;
  final String en;
  final List<String> aliases;

  String name(String languageCode) => languageCode == 'uk' ? uk : en;
}

class InteractionRule {
  const InteractionRule({
    required this.a,
    required this.b,
    required this.type,
    this.hours = 0,
    required this.uk,
    required this.en,
    this.source = '',
  });

  final String a;
  final String b;
  final RuleType type;

  /// Minimum gap for [RuleType.separate].
  final int hours;
  final String uk;
  final String en;
  final String source;

  String text(String languageCode) => languageCode == 'uk' ? uk : en;
}

class InteractionCatalog {
  InteractionCatalog({required this.substances, required this.rules})
    : _byKey = {for (final s in substances) s.key: s};

  factory InteractionCatalog.fromJson(Map<String, dynamic> json) =>
      InteractionCatalog(
        substances: [
          for (final s in json['substances'] as List)
            Substance(
              key: s['key'] as String,
              uk: s['uk'] as String,
              en: s['en'] as String,
              aliases: [for (final a in s['aliases'] as List) a as String],
            ),
        ],
        rules: [
          for (final r in json['rules'] as List)
            InteractionRule(
              a: r['a'] as String,
              b: r['b'] as String,
              type: RuleType.values.byName(r['type'] as String),
              hours: (r['hours'] as int?) ?? 0,
              uk: r['uk'] as String,
              en: r['en'] as String,
              source: (r['source'] as String?) ?? '',
            ),
        ],
      );

  final List<Substance> substances;
  final List<InteractionRule> rules;
  final Map<String, Substance> _byKey;

  Substance? substance(String key) => _byKey[key];

  /// Substances whose names appear in a medication name, e.g.
  /// "Магній B6" -> magnesium. Short aliases must match a whole word.
  Set<String> detect(String name) {
    final text =
        ' ${name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\-\x27]+', unicode: true), ' ')} ';
    return {
      for (final s in substances)
        if (s.aliases.any(
          (a) => a.length <= 3 ? text.contains(' $a ') : text.contains(a),
        ))
          s.key,
    };
  }

  List<InteractionRule> rulesFor(Set<String> a, Set<String> b) => [
    for (final r in rules)
      if ((a.contains(r.a) && b.contains(r.b)) ||
          (a.contains(r.b) && b.contains(r.a)))
        r,
  ];
}

/// A medication as the checker sees it.
class InteractionMed {
  const InteractionMed({
    required this.id,
    required this.name,
    required this.substances,
    required this.rules,
  });

  final int id;
  final String name;
  final Set<String> substances;

  /// Active schedules.
  final List<ScheduleRule> rules;

  List<DoseTime> get times => [
    for (final r in rules)
      if (r.dayPattern != DayPattern.asNeeded) ...r.times,
  ];
}

class InteractionIssue {
  const InteractionIssue({
    required this.a,
    required this.b,
    required this.rule,
    this.timeA,
    this.timeB,
  });

  final InteractionMed a;
  final InteractionMed b;
  final InteractionRule rule;

  /// For [RuleType.separate]: the two dose times that are too close.
  final DoseTime? timeA;
  final DoseTime? timeB;

  bool get isWarning => rule.type != RuleType.together;

  bool involves(int id) => a.id == id || b.id == id;

  /// The other medication from [id]'s point of view.
  InteractionMed other(int id) => a.id == id ? b : a;

  /// Earliest time for [id]'s dose that keeps the gap, if it is the same day.
  DoseTime? suggestionFor(int id) {
    if (timeA == null || timeB == null) return null;
    final mine = a.id == id ? timeA! : timeB!;
    final theirs = a.id == id ? timeB! : timeA!;
    final gap = rule.hours * 60;
    final later = theirs.minuteOfDay + gap;
    final earlier = theirs.minuteOfDay - gap;
    // Move the way that needs the smaller shift.
    final candidates = [if (later < 24 * 60) later, if (earlier >= 0) earlier]
      ..sort(
        (x, y) => (x - mine.minuteOfDay).abs().compareTo(
          (y - mine.minuteOfDay).abs(),
        ),
      );
    if (candidates.isEmpty) return null;
    final m = candidates.first;
    return DoseTime(hour: m ~/ 60, minute: m % 60, dose: mine.dose);
  }
}

int _gapMinutes(DoseTime x, DoseTime y) {
  final d = (x.minuteOfDay - y.minuteOfDay).abs();
  return d < 24 * 60 - d ? d : 24 * 60 - d;
}

/// Every rule that applies between pairs of [meds]. A "separate" rule is
/// reported only when two dose times are closer than its gap (the closest
/// pair is shown).
List<InteractionIssue> findInteractions(
  InteractionCatalog catalog,
  List<InteractionMed> meds,
) {
  final issues = <InteractionIssue>[];
  for (var i = 0; i < meds.length; i++) {
    for (var j = i + 1; j < meds.length; j++) {
      final a = meds[i];
      final b = meds[j];
      for (final rule in catalog.rulesFor(a.substances, b.substances)) {
        if (rule.type != RuleType.separate) {
          issues.add(InteractionIssue(a: a, b: b, rule: rule));
          continue;
        }
        (DoseTime, DoseTime)? closest;
        var best = 1 << 30;
        for (final ta in a.times) {
          for (final tb in b.times) {
            final g = _gapMinutes(ta, tb);
            if (g < rule.hours * 60 && g < best) {
              best = g;
              closest = (ta, tb);
            }
          }
        }
        if (closest != null) {
          issues.add(
            InteractionIssue(
              a: a,
              b: b,
              rule: rule,
              timeA: closest.$1,
              timeB: closest.$2,
            ),
          );
        }
      }
    }
  }
  return issues;
}
