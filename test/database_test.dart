import 'package:bady/data/database.dart';
import 'package:bady/domain/enums.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int med;
  final t = DateTime(2026, 11, 18, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    med = await db.insertMedication(
      MedicationsCompanion.insert(
        name: 'Магній',
        kind: MedKind.supplement,
        form: MedForm.tablet,
        stock: const Value(10),
      ),
    );
  });

  tearDown(() => db.close());

  Future<double?> stock() async => (await db.watchMedication(med).first)!.stock;

  Future<void> set(DoseStatus s) => db.setDoseStatus(
    medicationId: med,
    scheduledAt: t,
    dose: 2,
    status: s,
    actualAt: t,
  );

  test('taking decrements stock once, even if repeated', () async {
    await set(DoseStatus.taken);
    await set(DoseStatus.taken);
    expect(await stock(), 8);
    final events = await db.eventsBetween(t, t);
    expect(events.single.status, DoseStatus.taken);
  });

  test('switching from taken to skipped restores stock', () async {
    await set(DoseStatus.taken);
    await set(DoseStatus.skipped);
    expect(await stock(), 10);
  });

  test('clearing a taken dose restores stock and removes the row', () async {
    await set(DoseStatus.taken);
    await db.clearDose(med, t);
    expect(await stock(), 10);
    expect(await db.eventsBetween(t, t), isEmpty);
  });

  test('unscheduled doses are found by actual time', () async {
    await db.logUnscheduled(med, 1, t);
    final events = await db.eventsBetween(
      DateTime(2026, 11, 18),
      DateTime(2026, 11, 19),
    );
    expect(events.single.scheduledAt, isNull);
    expect(await stock(), 9);
    await db.deleteEvent(events.single.id);
    expect(await stock(), 10);
  });
}
