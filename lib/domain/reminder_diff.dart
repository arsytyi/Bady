/// Works out which scheduled reminders must change, so a resync touches only
/// the alarms that differ instead of cancelling and recreating all of them.
///
/// [desired] maps notification id to a signature of everything that makes
/// up the reminder (time, text, sound channel...). [previous] is what the
/// last sync stored and [pending] the ids Android still holds.
({List<int> cancel, List<int> schedule}) diffReminders({
  required Map<int, String> previous,
  required Set<int> pending,
  required Map<int, String> desired,
}) {
  final cancel = [
    for (final id in pending)
      if (!desired.containsKey(id)) id,
  ]..sort();
  final schedule = [
    for (final MapEntry(key: id, value: sig) in desired.entries)
      // Unknown or changed: (re)schedule. Rescheduling an id replaces it.
      if (!pending.contains(id) || previous[id] != sig) id,
  ];
  return (cancel: cancel, schedule: schedule);
}

/// FNV-1a of [text], stable across runs and isolates.
String stableHash(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}
