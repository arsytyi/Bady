import 'dart:convert';

/// Data carried by a reminder notification so actions can be handled
/// without opening the app.
class NotificationPayload {
  const NotificationPayload({required this.doseTime, required this.doses});

  final DateTime doseTime;

  /// medicationId -> dose
  final Map<int, double> doses;

  String encode() => jsonEncode({
    't': doseTime.millisecondsSinceEpoch,
    'd': {for (final e in doses.entries) '${e.key}': e.value},
  });

  static NotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        doseTime: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        doses: {
          for (final e in (json['d'] as Map<String, dynamic>).entries)
            int.parse(e.key): (e.value as num).toDouble(),
        },
      );
    } catch (_) {
      return null;
    }
  }
}

/// Notification action ids.
abstract final class NotificationActions {
  static const taken = 'taken';
  static const snooze = 'snooze';
  static const skip = 'skip';
}
