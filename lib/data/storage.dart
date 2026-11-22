import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill.dart';
import '../models/ledger_entry.dart';
import 'database.dart';

/// Abstraction เพื่อให้แอพใช้ได้ทั้งมือถือ (SQLite) และเว็บ (SharedPreferences)
abstract class AppStorage {
  factory AppStorage.create() => kIsWeb ? WebStorage() : SqliteStorage();

  Future<void> init();
  Future<List<Bill>> getBills();
  Future<void> upsertBill(Bill bill);
  Future<void> upsertBills(List<Bill> bills);
  Future<void> deleteBills(List<String> ids);
  Future<List<LedgerEntry>> getEntries();
  Future<void> upsertEntry(LedgerEntry entry);
  Future<void> upsertEntries(List<LedgerEntry> entries);
  Future<void> deleteEntry(String id);
  Future<Map<String, String>> getAllSettings();
  Future<void> setSetting(String key, String value);
  Future<void> setSettings(Map<String, String> values);

  Map<String, String>? settingsCache;
}

class SqliteStorage implements AppStorage {
  SqliteStorage() : _db = AppDatabase.instance;

  final AppDatabase _db;

  @override
  Map<String, String>? settingsCache;

  @override
  Future<void> init() => _db.init();

  @override
  Future<List<Bill>> getBills() => _db.getBills();

  @override
  Future<void> upsertBill(Bill bill) => _db.upsertBill(bill);

  @override
  Future<void> upsertBills(List<Bill> bills) => _db.upsertBills(bills);

  @override
  Future<void> deleteBills(List<String> ids) => _db.deleteBills(ids);

  @override
  Future<List<LedgerEntry>> getEntries() => _db.getEntries();

  @override
  Future<void> upsertEntry(LedgerEntry entry) => _db.upsertEntry(entry);

  @override
  Future<void> upsertEntries(List<LedgerEntry> entries) =>
      _db.upsertEntries(entries);

  @override
  Future<void> deleteEntry(String id) => _db.deleteEntry(id);

  @override
  Future<Map<String, String>> getAllSettings() => _db.getAllSettings();

  @override
  Future<void> setSetting(String key, String value) =>
      _db.setSetting(key, value);

  @override
  Future<void> setSettings(Map<String, String> values) =>
      _db.setSettings(values);
}

class WebStorage implements AppStorage {
  WebStorage();

  static const _billsKey = 'billandar_bills';
  static const _entriesKey = 'billandar_entries';
  static const _settingsKey = 'billandar_settings';

  SharedPreferences? _prefs;
  Map<String, String>? _bills;
  Map<String, String>? _entries;
  Map<String, String>? _settings;

  @override
  Map<String, String>? settingsCache;

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Map<String, String> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    return {for (final e in decoded.entries) e.key.toString(): e.value.toString()};
  }

  Future<Map<String, String>> _load(String key) async {
    final p = await prefs;
    return _decode(p.getString(key) ?? '{}');
  }

  Future<void> _save(String key, Map<String, String> value) async {
    final p = await prefs;
    await p.setString(key, jsonEncode(value));
  }

  @override
  Future<void> init() async {
    _bills ??= await _load(_billsKey);
    _entries ??= await _load(_entriesKey);
    _settings ??= await _load(_settingsKey);
    settingsCache = _settings;
  }

  @override
  Future<List<Bill>> getBills() async {
    _bills ??= await _load(_billsKey);
    return _bills!.values
        .map((raw) => Bill.fromMap(Map<String, dynamic>.from(jsonDecode(raw))))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    _bills ??= await _load(_billsKey);
    _bills![bill.id] = jsonEncode(bill.toMap());
    await _save(_billsKey, _bills!);
  }

  @override
  Future<void> upsertBills(List<Bill> bills) async {
    for (final bill in bills) {
      await upsertBill(bill);
    }
  }

  @override
  Future<void> deleteBills(List<String> ids) async {
    _bills ??= await _load(_billsKey);
    _bills!.removeWhere((key, _) => ids.contains(key));
    await _save(_billsKey, _bills!);
  }

  @override
  Future<List<LedgerEntry>> getEntries() async {
    _entries ??= await _load(_entriesKey);
    return _entries!.values
        .map((raw) =>
            LedgerEntry.fromMap(Map<String, dynamic>.from(jsonDecode(raw))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> upsertEntry(LedgerEntry entry) async {
    _entries ??= await _load(_entriesKey);
    _entries![entry.id] = jsonEncode(entry.toMap());
    await _save(_entriesKey, _entries!);
  }

  @override
  Future<void> upsertEntries(List<LedgerEntry> entries) async {
    for (final entry in entries) {
      await upsertEntry(entry);
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries ??= await _load(_entriesKey);
    _entries!.remove(id);
    await _save(_entriesKey, _entries!);
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    _settings ??= await _load(_settingsKey);
    settingsCache = _settings;
    return Map<String, String>.from(_settings!);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _settings ??= await _load(_settingsKey);
    _settings![key] = value;
    settingsCache = _settings;
    await _save(_settingsKey, _settings!);
  }

  @override
  Future<void> setSettings(Map<String, String> values) async {
    _settings ??= await _load(_settingsKey);
    _settings!.addAll(values);
    settingsCache = _settings;
    await _save(_settingsKey, _settings!);
  }
}
