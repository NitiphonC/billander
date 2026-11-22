import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/date_utils.dart';
import '../models/bill.dart';
import '../models/ledger_entry.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'billandar.db');
    final opened = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE bills (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount INTEGER NOT NULL,
            due_date TEXT NOT NULL,
            recurring INTEGER NOT NULL DEFAULT 0,
            series_id TEXT,
            paid_at TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_bills_due ON bills(due_date)');
        await db.execute('''
          CREATE TABLE ledger (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            date TEXT NOT NULL,
            bill_id TEXT,
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_ledger_date ON ledger(date)');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    _db = opened;
    return opened;
  }

  Future<void> init() async {
    await database;
  }

  Future<List<Bill>> getBills() async {
    final db = await database;
    final rows = await db.query('bills', orderBy: 'due_date ASC, created_at ASC');
    return rows.map(Bill.fromMap).toList();
  }

  Future<void> upsertBill(Bill bill) async {
    final db = await database;
    await db.insert('bills', bill.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertBills(List<Bill> bills) async {
    final db = await database;
    final batch = db.batch();
    for (final bill in bills) {
      batch.insert('bills', bill.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteBill(String id) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBills(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final marks = List.filled(ids.length, '?').join(', ');
    await db.delete('bills', where: 'id IN ($marks)', whereArgs: ids);
  }

  Future<List<LedgerEntry>> getEntries() async {
    final db = await database;
    final rows = await db.query(
      'ledger',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<void> upsertEntry(LedgerEntry entry) async {
    final db = await database;
    await db.insert('ledger', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertEntries(List<LedgerEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('ledger', entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('ledger', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> values) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    values.forEach((key, value) {
      batch.insert(
        'settings',
        {'key': key, 'value': value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  Future<void> exportToJson() async {
    // ใช้สำหรับสำรองข้อมูล manually (ดูใน SettingsScreen)
    final bills = await getBills();
    final entries = await getEntries();
    final settings = await getAllSettings();
    // ignore: avoid_print
    print({
      'bills': bills.map((b) => b.toMap()).toList(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'settings': settings,
    });
  }

  DateTime? parseSettingDate(String? key) => tryParseDateKey(key);
}

const String settingLastSeenDate = 'last_seen_date';
const String settingNotifications = 'notifications_enabled';
const String settingReminderHour = 'reminder_hour';
const String settingReminderMinute = 'reminder_minute';
const String settingSyncEnabled = 'sync_enabled';
const String settingLastSync = 'last_sync_at';
