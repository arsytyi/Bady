import 'package:bady/domain/reminder_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unchanged reminders are left alone', () {
    final d = diffReminders(
      previous: {1: 'a', 2: 'b'},
      pending: {1, 2},
      desired: {1: 'a', 2: 'b'},
    );
    expect(d.cancel, isEmpty);
    expect(d.schedule, isEmpty);
  });

  test('changed, new and missing reminders are scheduled', () {
    final d = diffReminders(
      previous: {1: 'a', 2: 'b', 3: 'c'},
      // 3 was cancelled after the dose was logged.
      pending: {1, 2},
      desired: {1: 'a', 2: 'B', 3: 'c', 4: 'd'},
    );
    expect(d.cancel, isEmpty);
    expect(d.schedule, [2, 3, 4]);
  });

  test('reminders no longer planned are cancelled', () {
    final d = diffReminders(
      previous: {1: 'a', 2: 'b'},
      // 9 was scheduled elsewhere (e.g. a snooze) and is not in the plan.
      pending: {1, 2, 9},
      desired: {1: 'a'},
    );
    expect(d.cancel, [2, 9]);
    expect(d.schedule, isEmpty);
  });

  test('a lost record reschedules everything once', () {
    final d = diffReminders(
      previous: const {},
      pending: {1, 2},
      desired: {1: 'a', 2: 'b'},
    );
    expect(d.schedule, [1, 2]);
  });

  test('stableHash is stable', () {
    expect(stableHash('raw:bady_chime'), stableHash('raw:bady_chime'));
    expect(stableHash('a'), isNot(stableHash('b')));
  });
}
