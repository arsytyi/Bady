import 'package:bady/data/backup.dart';
import 'package:bady/data/database.dart';
import 'package:bady/domain/enums.dart';
import 'package:bady/domain/look.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final rule = ScheduleRule(
    startDate: DateTime(2026, 11, 1),
    dayPattern: DayPattern.weekdays,
    weekdays: const {1, 3, 5},
    times: const [DoseTime(hour: 8, minute: 30, dose: 2)],
  );

  Future<int> seed(AppDatabase db) async {
    final id = await db.insertMedication(
      MedicationsCompanion.insert(
        name: 'Омега-3',
        kind: MedKind.supplement,
        form: MedForm.capsule,
        unit: const Value('@capsule'),
        color2: const Value(0xFFFFFFFF),
        shape: const Value(PillShape.softgel),
        stock: const Value(40),
        packSize: const Value(60),
        notes: const Value('після їжі'),
      ),
    );
    await db.insertSchedule(id, rule);
    await db.setDoseStatus(
      medicationId: id,
      scheduledAt: DateTime(2026, 11, 18, 8, 30),
      dose: 2,
      status: DoseStatus.taken,
      actualAt: DateTime(2026, 11, 18, 8, 41),
    );
    return id;
  }

  test('export then restore gives back the same data', () async {
    await seed(db);
    final json = await Backup.export(db);
    expect(Backup.inspect(json), (medications: 1, schedules: 1, doseEvents: 1));

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.insertMedication(
      MedicationsCompanion.insert(
        name: 'Буде замінено',
        kind: MedKind.medicine,
        form: MedForm.tablet,
      ),
    );
    await Backup.restore(other, json);

    final meds = await other.select(other.medications).get();
    expect(meds.single.name, 'Омега-3');
    expect(meds.single.shape, PillShape.softgel);
    expect(meds.single.stock, 38); // 40 minus the taken dose
    expect(meds.single.notes, 'після їжі');
    final schedules = await other.select(other.schedules).get();
    expect(schedules.single.rule.toJson(), rule.toJson());
    final events = await other.select(other.doseEvents).get();
    expect(events.single.status, DoseStatus.taken);
    expect(events.single.actualAt, DateTime(2026, 11, 18, 8, 41));
    // Restoring again (e.g. a second tap) still works.
    await Backup.restore(other, json);
    expect(await other.select(other.medications).get(), hasLength(1));
  });

  test('rejects files that are not a valid backup and keeps data', () async {
    await seed(db);
    for (final bad in [
      'hello',
      '{"app":"other"}',
      '{"app":"bady","format":99}',
      '{"app":"bady","format":1,"medications":[{"id":1}],'
          '"schedules":[],"doseEvents":[]}',
      '{"app":"bady","format":1,"medications":[],'
          '"schedules":[{"id":1,"medicationId":5}],"doseEvents":[]}',
    ]) {
      expect(
        () => Backup.restore(db, bad),
        throwsA(isA<BackupFormatException>()),
        reason: bad,
      );
    }
    expect(await db.select(db.medications).get(), hasLength(1));
  });

  test('file name has the date', () {
    expect(
      Backup.fileName(DateTime(2026, 3, 5)),
      'bady-backup-2026-03-05.json',
    );
  });
}
