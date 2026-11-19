/// Backup of all user data as one JSON document.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/schedule_rule.dart';
import 'database.dart';

/// Thrown when a file is not a Bady backup or is damaged.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

abstract final class Backup {
  static const app = 'bady';
  static const format = 1;

  /// File name such as `bady-backup-2026-11-19.json`.
  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'bady-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  static Future<String> export(AppDatabase db, {DateTime? now}) async {
    final meds = await db.select(db.medications).get();
    final schedules = await db.select(db.schedules).get();
    final events = await db.select(db.doseEvents).get();
    return const JsonEncoder.withIndent(' ').convert({
      'app': app,
      'format': format,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'medications': [for (final m in meds) m.toJson()],
      'schedules': [
        for (final s in schedules)
          {
            'id': s.id,
            'medicationId': s.medicationId,
            'rule': s.rule.toJson(),
            'active': s.active,
            'createdAt': s.createdAt.millisecondsSinceEpoch,
          },
      ],
      'doseEvents': [for (final e in events) e.toJson()],
    });
  }

  /// Counts of what a backup holds, checked before anything is replaced.
  static ({int medications, int schedules, int doseEvents}) inspect(
    String json,
  ) {
    final d = _parse(json);
    return (
      medications: d.meds.length,
      schedules: d.schedules.length,
      doseEvents: d.events.length,
    );
  }

  /// Replaces all data with the backup. Nothing changes if it is invalid.
  static Future<void> restore(AppDatabase db, String json) async {
    final d = _parse(json);
    await db.transaction(() async {
      await db.delete(db.doseEvents).go();
      await db.delete(db.schedules).go();
      await db.delete(db.medications).go();
      await db.batch((b) {
        b.insertAll(db.medications, d.meds);
        b.insertAll(db.schedules, d.schedules);
        b.insertAll(db.doseEvents, d.events);
      });
    });
  }

  static ({
    List<Medication> meds,
    List<SchedulesCompanion> schedules,
    List<DoseEvent> events,
  })
  _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupFormatException('not JSON');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != app) {
      throw const BackupFormatException('not a Bady backup');
    }
    final root = decoded;
    final version = root['format'];
    if (version is! int || version > format) {
      throw const BackupFormatException('made by a newer version');
    }
    try {
      List<Map<String, dynamic>> list(String key) {
        final v = root[key];
        if (v is! List) throw BackupFormatException('missing $key');
        return v.cast<Map<String, dynamic>>();
      }

      final meds = [
        for (final m in list('medications')) Medication.fromJson(m),
      ];
      final ids = {for (final m in meds) m.id};
      final schedules = [
        for (final s in list('schedules'))
          SchedulesCompanion.insert(
            id: Value(s['id'] as int),
            medicationId: s['medicationId'] as int,
            rule: ScheduleRule.fromJson(s['rule'] as Map<String, dynamic>),
            active: Value(s['active'] as bool),
            createdAt: Value(
              DateTime.fromMillisecondsSinceEpoch(s['createdAt'] as int),
            ),
          ),
      ];
      final events = [
        for (final e in list('doseEvents')) DoseEvent.fromJson(e),
      ];
      final orphan =
          schedules.any((s) => !ids.contains(s.medicationId.value)) ||
          events.any((e) => !ids.contains(e.medicationId));
      if (orphan) throw const BackupFormatException('broken references');
      return (meds: meds, schedules: schedules, events: events);
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      throw BackupFormatException('damaged: $e');
    }
  }
}
