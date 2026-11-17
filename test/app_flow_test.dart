import 'package:bady/app.dart';
import 'package:bady/data/database.dart';
import 'package:bady/domain/enums.dart';
import 'package:bady/domain/schedule_rule.dart';
import 'package:bady/providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Unmounts the app so drift stream-close timers fire inside the test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<void> pumpApp(WidgetTester tester, {String locale = 'uk'}) async {
    SharedPreferences.setMockInitialValues({'locale': locale});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const BadyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty today screen in Ukrainian', (tester) async {
    await pumpApp(tester);
    expect(find.text('На сьогодні прийомів немає'), findsOneWidget);
    expect(find.text('Препарати'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('English UI when chosen', (tester) async {
    await pumpApp(tester, locale: 'en');
    expect(find.text('No doses planned for today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('add a medication through the form', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Препарати'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Додати препарат'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Магній B6');
    await tester.tap(find.text('Зберегти'));
    await tester.pumpAndSettle();

    final meds = (await tester.runAsync(() => db.watchMedications().first))!;
    expect(meds.single.name, 'Магній B6');
    expect(meds.single.kind, MedKind.supplement);
    // Lands on the detail screen with an add-schedule button.
    expect(find.text('Додати розклад'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scheduled dose shows on the today screen', (tester) async {
    await tester.runAsync(() async {
      final id = await db.insertMedication(
        MedicationsCompanion.insert(
          name: 'Вітамін D',
          kind: MedKind.supplement,
          form: MedForm.capsule,
          unit: const Value('капс.'),
        ),
      );
      await db.insertSchedule(
        id,
        ScheduleRule(
          startDate: DateTime.now(),
          times: const [DoseTime(hour: 23, minute: 59)],
        ),
      );
    });
    await pumpApp(tester);
    expect(find.text('Вітамін D'), findsOneWidget);
    expect(find.text('23:59'), findsOneWidget);
    expect(find.text('1 капс.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('schedule editor validates and saves', (tester) async {
    final id = (await tester.runAsync(
      () => db.insertMedication(
        MedicationsCompanion.insert(
          name: 'Залізо',
          kind: MedKind.supplement,
          form: MedForm.tablet,
        ),
      ),
    ))!;
    await pumpApp(tester);
    await tester.tap(find.text('Препарати'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Залізо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Додати розклад'));
    await tester.pumpAndSettle();

    // Switch to "every N days" and save with the default interval of 2.
    await tester.tap(find.text('Кожні N днів'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Зберегти'));
    await tester.pumpAndSettle();

    final schedules = (await tester.runAsync(
      () => db.watchSchedulesFor(id).first,
    ))!;
    expect(schedules.single.rule.dayPattern, DayPattern.everyNDays);
    expect(schedules.single.rule.everyNDays, 2);
    expect(find.textContaining('кожні 2 дні'), findsOneWidget);
    await unmount(tester);
  });
}
