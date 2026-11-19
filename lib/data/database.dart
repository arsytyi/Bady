import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/dose_plan.dart';
import '../domain/enums.dart';
import '../domain/look.dart';
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

  /// Second color for two-tone capsules.
  IntColumn get color2 => integer().nullable()();

  /// Null means the default shape for [form].
  IntColumn get shape => intEnum<PillShape>().nullable()();
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
/// At most one row per medication and scheduled time.
@TableIndex(
  name: 'dose_events_med_time',
  columns: {#medicationId, #scheduledAt},
  unique: true,
)
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
    : super(
        executor ??
            driftDatabase(
              name: 'bady',
              // Notification actions run in a background isolate.
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createIndex(doseEventsMedTime);
      }
      if (from < 3) {
        await m.addColumn(medications, medications.color2);
        await m.addColumn(medications, medications.shape);
      }
    },
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

  // Dose log

  Expression<bool> _eventInRange(DateTime from, DateTime to) =>
      doseEvents.scheduledAt.isBetweenValues(from, to) |
      (doseEvents.scheduledAt.isNull() &
          doseEvents.actualAt.isBetweenValues(from, to));

  /// Events whose scheduled time (or actual time, for unscheduled doses)
  /// falls in [from, to].
  Stream<List<DoseEvent>> watchEventsBetween(DateTime from, DateTime to) =>
      (select(doseEvents)..where((_) => _eventInRange(from, to))).watch();

  Future<List<DoseEvent>> eventsBetween(DateTime from, DateTime to) =>
      (select(doseEvents)..where((_) => _eventInRange(from, to))).get();

  Future<DoseEvent?> _eventFor(int medicationId, DateTime scheduledAt) =>
      (select(doseEvents)..where(
            (e) =>
                e.medicationId.equals(medicationId) &
                e.scheduledAt.equals(scheduledAt),
          ))
          .getSingleOrNull();

  /// Sets stock tracking for a medication; [stock] null stops tracking.
  Future<void> setStockSettings(
    int id, {
    required double? stock,
    required double? packSize,
    required int lowStockDays,
  }) => (update(medications)..where((m) => m.id.equals(id))).write(
    MedicationsCompanion(
      stock: Value(stock),
      packSize: Value(packSize),
      lowStockDays: Value(lowStockDays),
    ),
  );

  /// Adds bought units; starts tracking if it was off.
  Future<void> addStock(int id, double amount) => customUpdate(
    'UPDATE medications SET stock = MAX(COALESCE(stock, 0) + ?, 0) '
    'WHERE id = ?',
    variables: [Variable.withReal(amount), Variable.withInt(id)],
    updates: {medications},
  );

  /// Adds [delta] to a medication's stock when stock is tracked.
  Future<void> _adjustStock(int medicationId, double delta) async {
    if (delta == 0) return;
    await customUpdate(
      'UPDATE medications SET stock = MAX(stock + ?, 0) '
      'WHERE id = ? AND stock IS NOT NULL',
      variables: [Variable.withReal(delta), Variable.withInt(medicationId)],
      updates: {medications},
    );
  }

  /// Records what happened with a scheduled dose. Idempotent: logging the
  /// same status twice changes nothing, and stock only moves when a dose
  /// becomes taken or stops being taken.
  Future<void> setDoseStatus({
    required int medicationId,
    required DateTime scheduledAt,
    required double dose,
    required DoseStatus status,
    required DateTime actualAt,
  }) => transaction(() async {
    final existing = await _eventFor(medicationId, scheduledAt);
    final wasTaken = existing?.status == DoseStatus.taken;
    final isTaken = status == DoseStatus.taken;
    if (existing == null) {
      await into(doseEvents).insert(
        DoseEventsCompanion.insert(
          medicationId: medicationId,
          scheduledAt: Value(scheduledAt),
          actualAt: Value(actualAt),
          dose: dose,
          status: status,
        ),
      );
    } else {
      if (existing.status == status && status != DoseStatus.snoozed) return;
      await (update(doseEvents)..where((e) => e.id.equals(existing.id))).write(
        DoseEventsCompanion(
          status: Value(status),
          actualAt: Value(actualAt),
          dose: Value(dose),
        ),
      );
    }
    if (isTaken && !wasTaken) await _adjustStock(medicationId, -dose);
    if (!isTaken && wasTaken) await _adjustStock(medicationId, existing!.dose);
  });

  /// Removes the log entry for a scheduled dose, restoring stock if needed.
  Future<void> clearDose(int medicationId, DateTime scheduledAt) =>
      transaction(() async {
        final existing = await _eventFor(medicationId, scheduledAt);
        if (existing == null) return;
        await (delete(doseEvents)..where((e) => e.id.equals(existing.id))).go();
        if (existing.status == DoseStatus.taken) {
          await _adjustStock(medicationId, existing.dose);
        }
      });

  /// Logs a dose taken outside any schedule ("as needed").
  Future<void> logUnscheduled(int medicationId, double dose, DateTime at) =>
      transaction(() async {
        await into(doseEvents).insert(
          DoseEventsCompanion.insert(
            medicationId: medicationId,
            actualAt: Value(at),
            dose: dose,
            status: DoseStatus.taken,
          ),
        );
        await _adjustStock(medicationId, -dose);
      });

  Future<void> deleteEvent(int id) => transaction(() async {
    final e = await (select(
      doseEvents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (e == null) return;
    await (delete(doseEvents)..where((t) => t.id.equals(id))).go();
    if (e.status == DoseStatus.taken) {
      await _adjustStock(e.medicationId, e.dose);
    }
  });
}

extension MedicationLook on Medication {
  PillShape get pillShape => shape ?? defaultShapeFor(form);

  PillLook get look => PillLook(shape: pillShape, color: color, color2: color2);
}

extension DoseEventToLogged on DoseEvent {
  LoggedDose toLogged() => LoggedDose(
    id: id,
    medicationId: medicationId,
    scheduledAt: scheduledAt,
    status: status,
    dose: dose,
    actualAt: actualAt,
  );
}

class PlannedSchedule {
  const PlannedSchedule(this.medication, this.schedule);

  final Medication medication;
  final Schedule schedule;
}
