import 'package:bady/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each sound gets its own stable channel', () {
    expect(NotificationService.channelIdFor(null), 'dose_reminders');
    final chime = NotificationService.channelIdFor('raw:bady_chime');
    expect(chime, startsWith('dose_'));
    expect(NotificationService.channelIdFor('raw:bady_chime'), chime);
    expect(NotificationService.channelIdFor('raw:bady_bell'), isNot(chime));
  });
}
