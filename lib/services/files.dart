import 'package:flutter/services.dart';

import 'notification_service.dart';

/// Saving and opening files through the Android file picker (MainActivity).
abstract final class DeviceFiles {
  static const _channel = MethodChannel('bady/files');

  static bool get supported => NotificationService.supported;

  /// Lets the user choose where to save [text]. False when cancelled.
  static Future<bool> save(String name, String text) async {
    final ok = await _channel.invokeMethod<bool>('save', {
      'name': name,
      'text': text,
    });
    return ok ?? false;
  }

  /// Lets the user pick a file and returns its text, or null when cancelled.
  static Future<String?> open() => _channel.invokeMethod<String>('open');
}
