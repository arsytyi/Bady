import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/enums.dart';
import '../domain/schedule_rule.dart';

part 'database.g.dart';

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get kind => intEnum<MedKind>()();
  IntColumn get form => intEnum<MedForm>()();

  /// Free-text unit shown next to doses, e.g. "табл.", "мг", "мл".
  TextColumn get unit => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0xFF4F7DF3))();
  IntColumn get meal =>
      intEnum<MealRelation>().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Units left in stock; null when stock isn't tracked.
  RealColumn get stock => real().nullable()();
  RealColumn get packSize => real().nullable()();
  IntColumn get lowStockDays => integer().withDefault(const Constant(7))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A schedule belongs to a medication. The rule (days, times, duration) is
/// stored as JSON so the format can evolve without table migrations.
class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId =>
      integer().references(Medications, #id, onDelete: KeyAction.cascade)();
  TextColumn get rule => text().map(const ScheduleRuleConverter())();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// What actually happened with a dose. Future doses are computed from
/// schedules and are not stored, so editing a schedule never rewrites history.
class DoseEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId =>
      integer().references(Medications, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get actualAt => dateTime().nullable()();
  RealColumn get dose => real()();
  IntColumn get status => intEnum<DoseStatus>()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class ScheduleRuleConverter extends TypeConverter<ScheduleRule, String> {
  const ScheduleRuleConverter();

  @override
  ScheduleRule fromSql(String fromDb) =>
      ScheduleRule.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(ScheduleRule value) => jsonEncode(value.toJson());
}

@DriftDatabase(tables: [Medications, Schedules, DoseEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bady'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // Medications

  Stream<List<Medication>> watchMedications({bool archived = false}) =>
      (select(medications)
            ..where((m) => m.archived.equals(archived))
            ..orderBy([(m) => OrderingTerm.asc(m.name.lower())]))
          .watch();

  Stream<Medication?> watchMedication(int id) =>
      (select(medications)..where((m) => m.id.equals(id))).watchSingleOrNull();

  Future<int> insertMedication(MedicationsCompanion entry) =>
      into(medications).insert(entry);

  Future<void> updateMedication(int id, MedicationsCompanion entry) =>
      (update(medications)..where((m) => m.id.equals(id))).write(entry);

  Future<void> deleteMedication(int id) =>
      (delete(medications)..where((m) => m.id.equals(id))).go();

  // Schedules

  Stream<List<Schedule>> watchSchedulesFor(int medicationId) =>
      (select(schedules)
            ..where((s) => s.medicationId.equals(medicationId))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
          .watch();

  Future<Schedule?> getSchedule(int id) =>
      (select(schedules)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSchedule(int medicationId, ScheduleRule rule) => into(
    schedules,
  ).insert(SchedulesCompanion.insert(medicationId: medicationId, rule: rule));

  Future<void> updateSchedule(int id, ScheduleRule rule) =>
      (update(schedules)..where((s) => s.id.equals(id))).write(
        SchedulesCompanion(rule: Value(rule)),
      );

  Future<void> setScheduleActive(int id, bool active) =>
      (update(schedules)..where((s) => s.id.equals(id))).write(
        SchedulesCompanion(active: Value(active)),
      );

  Future<void> deleteSchedule(int id) =>
      (delete(schedules)..where((s) => s.id.equals(id))).go();

  /// Every active schedule of every non-archived medication.
  Stream<List<PlannedSchedule>> watchActivePlan() {
    final query =
        select(schedules).join([
          innerJoin(
            medications,
            medications.id.equalsExp(schedules.medicationId),
          ),
        ])..where(
          schedules.active.equals(true) & medications.archived.equals(false),
        );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PlannedSchedule(row.readTable(medications), row.readTable(schedules)),
      ],
    );
  }

  Future<List<PlannedSchedule>> activePlan() => watchActivePlan().first;
}

class PlannedSchedule {
  const PlannedSchedule(this.medication, this.schedule);

  final Medication medication;
  final Schedule schedule;
}
