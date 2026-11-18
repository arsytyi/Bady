import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

/// Result of the Android sound picker.
typedef PickedSound = ({String? sound, String? title});

/// Talks to MainActivity: the system notification-sound picker (which also
/// lets the user add their own file) and sound preview.
abstract final class SoundPicker {
  static const _channel = MethodChannel('bady/sound');

  /// Null when the user cancelled; `sound: null` means the phone default.
  static Future<PickedSound?> pick(String? current) async {
    if (!NotificationService.supported) return null;
    try {
      final r = await _channel.invokeMapMethod<String, String?>('pick', {
        'current': current,
      });
      if (r == null) return null;
      final uri = r['uri'];
      if (uri == null || uri == 'default') return (sound: null, title: null);
      return (sound: uri, title: r['title']);
    } on PlatformException catch (e) {
      debugPrint('Sound picker failed: $e');
      return null;
    }
  }

  static Future<void> play(String? sound) async {
    if (!NotificationService.supported) return;
    await _channel.invokeMethod('play', {'sound': sound});
  }

  static Future<void> stop() async {
    if (!NotificationService.supported) return;
    await _channel.invokeMethod('stop');
  }
}
