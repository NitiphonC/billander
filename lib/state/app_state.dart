import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/calculator.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../data/database.dart';
import '../data/storage.dart';
import '../models/bill.dart';
import '../models/ledger_entry.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_'
    '${Random().nextInt(1 << 30).toRadixString(36)}';

enum PaymentResult { success, insufficient, notFound }

class AppState extends ChangeNotifier {
  AppState({SyncService? sync, AppStorage? storage})
      : _sync = sync ?? NoopSyncService(),
        _db = storage ?? AppStorage.create();

  final SyncService _sync;
  final AppStorage _db;
  final NotificationService _notifications = NotificationService.instance;

  List<Bill> _bills = const [];
  List<LedgerEntry> _entries = const [];
  final Map<String, String> _settings = <String, String>{};

  bool loading = true;
  String? error;
  bool dayRollover = false;
  UpdateInfo? availableUpdate;
  DateTime _today = dateOnly(DateTime.now());
  Timer? _dayTimer;

  List<Bill> get bills => List.unmodifiable(_bills);
  List<LedgerEntry> get entries => List.unmodifiable(_entries);
  DateTime get today => _today;

  int get poolSatang =>
      _entries.fold<int>(0, (sum, e) => sum + e.amountSatang);

  SavingsPlan get plan => Calculator.calculate(
        bills: _bills,
        poolSatang: poolSatang,
        today: _today,
      );

  LedgerEntry? get initialEntry {
    for (final entry in _entries) {
      if (entry.type == LedgerType.initial) return entry;
    }
    return null;
  }

  bool get notificationsEnabled => _settings[settingNotifications] != 'false';

  TimeOfDay get reminderTime {
    final h = int.tryParse(_settings[settingReminderHour] ?? '') ?? 8;
    final m = int.tryParse(_settings[settingReminderMinute] ?? '') ?? 0;
    return TimeOfDay(
      hour: h.clamp(0, 23).toInt(),
      minute: m.clamp(0, 59).toInt(),
    );
  }

  bool get syncEnabled => _settings[settingSyncEnabled] == 'true';
  bool get syncConfigured => _sync.isConfigured;
  String? get lastSyncAt => _settings[settingLastSync];
  String get updateUrl => _settings[settingUpdateUrl] ?? '';

  /// ข้อความ error ที่โชว์ผู้ใช้ได้ (ไม่โชว์ technical exception)
  String? get userError {
    if (error == null) return null;
    if (error!.startsWith('ซิงก์ไม่สำเร็จ')) {
      return 'ซิงก์ข้อมูลไม่สำเร็จ — ข้อมูลในเครื่องยังปลอดภัย';
    }
    return 'เกิดปัญหาเล็กน้อย — ข้อมูลในเครื่องยังปลอดภัย';
  }

  Bill? billById(String id) {
    for (final bill in _bills) {
      if (bill.id == id) return bill;
    }
    return null;
  }

  List<Bill> billsForMonth(DateTime month) {
    return _bills
        .where((b) =>
            b.dueDate.year == month.year && b.dueDate.month == month.month)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Bill> activeBills() {
    return _bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<LedgerEntry> entriesForDate(DateTime date) {
    return _entries
        .where((e) => dateKey(e.date) == dateKey(date))
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  List<LedgerEntry> entriesForMonth(DateTime month) {
    return _entries
        .where((e) =>
            e.date.year == month.year && e.date.month == month.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      await _sync.initialize();
      await _db.init();

      _settings.clear();
      _settings.addAll(await _db.getAllSettings());
      await _pullFromCloudOnce();

      _bills = await _db.getBills();
      _entries = await _db.getEntries();
      _settings.clear();
      _settings.addAll(await _db.getAllSettings());

      await _materializeRecurring();

      if (initialEntry == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final entry = LedgerEntry(
          id: newId(),
          type: LedgerType.initial,
          amountSatang: 0,
          date: _today,
          createdAtMs: now,
          updatedAtMs: now,
        );
        await _db.upsertEntry(entry);
        _entries = [..._entries, entry];
      }

      await checkDayChange();
      await checkForUpdate();
      _dayTimer ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => checkDayChange(),
      );
      await _refreshNotification();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> checkDayChange() async {
    final now = dateOnly(DateTime.now());
    final last = _settings[settingLastSeenDate];
    final changed = last != null && last != dateKey(now);
    _today = now;
    if (last != dateKey(now)) {
      await _setSettingSilent(settingLastSeenDate, dateKey(now));
    }
    if (changed) {
      dayRollover = true;
      await _refreshNotification();
      notifyListeners();
    }
  }

  void acknowledgeDayRollover() {
    dayRollover = false;
  }

  /// เช็กอัปเดตจาก GitHub raw (อย่างน้อย 12 ชม. ต่อครั้ง เว้นแต่ force)
  Future<void> checkForUpdate({bool force = false}) async {
    if (kIsWeb) return;
    final url = _settings[settingUpdateUrl] ?? '';
    if (url.isEmpty) return;
    final lastRaw = _settings[settingLastUpdateCheck];
    if (!force && lastRaw != null) {
      final last = DateTime.tryParse(lastRaw);
      if (last != null &&
          DateTime.now().difference(last).inHours < 12) {
        return;
      }
    }
    try {
      availableUpdate = await UpdateService.instance.check(url);
      await _setSettingSilent(
        settingLastUpdateCheck,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      availableUpdate = null;
    }
  }

  Future<void> openUpdateDownload() async {
    final info = availableUpdate;
    if (info == null) return;
    await UpdateService.instance.openDownload(info.apkUrl);
  }

  Future<void> _materializeRecurring() async {
    final horizon = addMonthsClamped(_today, 12);
    final groups = <String, List<Bill>>{};
    for (final bill in _bills) {
      final seriesId = bill.seriesId;
      if (bill.recurring && seriesId != null) {
        (groups[seriesId] ??= <Bill>[]).add(bill);
      }
    }

    for (final group in groups.entries) {
      final members = group.value
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final anchor = members.first;
      var cursor = anchor.dueDate.isBefore(firstDayOfMonth(_today))
          ? firstDayOfMonth(_today)
          : anchor.dueDate;
      var guard = 0;
      while (!cursor.isAfter(horizon) && guard < 60) {
        guard++;
        final exists = members
            .any((b) => dateKey(b.dueDate) == dateKey(cursor));
        if (!exists) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final created = Bill(
            id: newId(),
            title: anchor.title,
            amountSatang: anchor.amountSatang,
            dueDate: cursor,
            recurring: true,
            seriesId: group.key,
            createdAtMs: now,
            updatedAtMs: now,
          );
          await _db.upsertBill(created);
          _bills = [..._bills, created];
          members.add(created);
        }
        cursor = addMonthsClamped(cursor, 1);
      }
    }
  }

  Future<void> addBill({
    required String title,
    required int amountSatang,
    required DateTime dueDate,
    required bool recurring,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId();
    final bill = Bill(
      id: id,
      title: title.trim(),
      amountSatang: amountSatang.abs(),
      dueDate: dateOnly(dueDate),
      recurring: recurring,
      seriesId: recurring ? id : null,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.upsertBill(bill);
    _bills = [..._bills, bill];
    if (recurring) await _materializeRecurring();
    await _commit();
  }

  Future<void> updateBill({
    required String billId,
    required String title,
    required int amountSatang,
    required DateTime dueDate,
    required bool recurring,
    required bool applyToFuture,
  }) async {
    final original = billById(billId);
    if (original == null) return;

    // บิลซ้ำทุกเดือนต้องเลื่อนวันจ่ายทุกงวดที่ยังไม่จ่ายด้วย
    // มิเช่นนั้นจะเหลือบิลเก่าที่วันเดิมซ้ำกับบิลที่แก้ใหม่
    final shouldUpdateSeries =
        (recurring || applyToFuture) && original.seriesId != null;
    final targets = shouldUpdateSeries
        ? _bills
            .where((b) =>
                b.seriesId == original.seriesId && !b.isPaid)
            .toList()
        : <Bill>[original];

    final now = DateTime.now().millisecondsSinceEpoch;
    final newAnchorDate = dateOnly(dueDate);
    final anchorMonth = monthIndex(original.dueDate);
    final updated = <Bill>[];
    for (final target in targets) {
      final monthOffset = monthIndex(target.dueDate) - anchorMonth;
      final next = target.copyWith(
        title: title.trim(),
        amountSatang: amountSatang.abs(),
        dueDate: shouldUpdateSeries
            ? addMonthsClamped(newAnchorDate, monthOffset)
            : newAnchorDate,
        recurring: recurring,
        clearSeriesId: !recurring,
        updatedAtMs: now,
      );
      await _db.upsertBill(next);
      updated.add(next);
    }
    _replaceBills(updated);
    if (recurring) await _materializeRecurring();
    await _commit();
  }

  Future<void> deleteBill(String billId, {bool includeFuture = false}) async {
    final bill = billById(billId);
    if (bill == null) return;
    final ids = <String>{billId};
    if (includeFuture && bill.seriesId != null) {
      ids.addAll(_bills
          .where((b) =>
              b.seriesId == bill.seriesId &&
              !b.dueDate.isBefore(bill.dueDate) &&
              !b.isPaid)
          .map((b) => b.id));
    }
    await _db.deleteBills(ids.toList());
    _bills = _bills.where((b) => !ids.contains(b.id)).toList();
    await _commit();
  }

  Future<PaymentResult> markPaid(String billId) async {
    final bill = billById(billId);
    if (bill == null || bill.isPaid) return PaymentResult.notFound;
    if (!Calculator.canPay(
      poolSatang: poolSatang,
      billAmountSatang: bill.amountSatang,
    )) {
      return PaymentResult.insufficient;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = LedgerEntry(
      id: newId(),
      type: LedgerType.payment,
      amountSatang: -bill.amountSatang,
      date: _today,
      billId: bill.id,
      note: 'จ่าย ${bill.title}',
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.upsertEntry(entry);
    _entries = [..._entries, entry];

    final paid = bill.copyWith(paidAt: DateTime.now(), updatedAtMs: now);
    await _db.upsertBill(paid);
    _replaceBills([paid]);

    await _materializeRecurring();
    await _commit();
    return PaymentResult.success;
  }

  Future<void> recordDeposit(int amountSatang, {String? note}) =>
      _recordEntry(LedgerType.deposit, amountSatang.abs(), note);

  Future<void> recordWithdrawal(int amountSatang, {String? note}) =>
      _recordEntry(LedgerType.withdrawal, -amountSatang.abs(), note);

  Future<void> _recordEntry(
    LedgerType type,
    int signedAmount,
    String? note,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = LedgerEntry(
      id: newId(),
      type: type,
      amountSatang: signedAmount,
      date: _today,
      note: note,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.upsertEntry(entry);
    _entries = [..._entries, entry];
    await _commit();
  }

  Future<void> setInitialBalance(int amountSatang) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = initialEntry;
    final entry = current == null
        ? LedgerEntry(
            id: newId(),
            type: LedgerType.initial,
            amountSatang: amountSatang,
            date: _today,
            createdAtMs: now,
            updatedAtMs: now,
          )
        : current.copyWith(amountSatang: amountSatang, updatedAtMs: now);
    await _db.upsertEntry(entry);
    if (current == null) {
      _entries = [..._entries, entry];
    } else {
      _entries = [
        for (final e in _entries) if (e.id == entry.id) entry else e,
      ];
    }
    await _commit();
  }

  Future<void> updateSetting(String key, String value) async {
    await _setSettingSilent(key, value);
    if (key == settingNotifications ||
        key == settingReminderHour ||
        key == settingReminderMinute) {
      await _refreshNotification();
    }
    if (key == settingSyncEnabled && syncEnabled) {
      await syncNow();
    }
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!syncEnabled || !_sync.isConfigured) return;
    try {
      await _sync.signIn();
      await _sync.push(
        bills: _bills,
        entries: _entries,
        settings: _settings,
      );
      await _pullFromCloudOnce();
      _bills = await _db.getBills();
      _entries = await _db.getEntries();
      await _setSettingSilent(
          settingLastSync, DateTime.now().toIso8601String());
      error = null;
    } catch (e) {
      error = 'ซิงก์ไม่สำเร็จ: $e';
    }
    notifyListeners();
  }

  Future<void> _pullFromCloudOnce() async {
    if (!syncEnabled || !_sync.isConfigured) return;
    await _sync.signIn();
    final snapshot = await _sync.pull();
    if (snapshot == null) return;

    final localBills = {for (final b in await _db.getBills()) b.id: b};
    final remoteBills = snapshot.bills.where((remote) {
      final local = localBills[remote.id];
      return local == null || remote.updatedAtMs >= local.updatedAtMs;
    }).toList();
    await _db.upsertBills(remoteBills);

    final localEntries = {for (final e in await _db.getEntries()) e.id: e};
    final remoteEntries = snapshot.entries.where((remote) {
      final local = localEntries[remote.id];
      return local == null || remote.updatedAtMs >= local.updatedAtMs;
    }).toList();
    await _db.upsertEntries(remoteEntries);

    final merged = <String, String>{..._settings, ...snapshot.settings};
    await _db.setSettings(merged);
  }

  Future<void> _setSettingSilent(String key, String value) async {
    await _db.setSetting(key, value);
    _settings[key] = value;
  }

  Future<void> _refreshNotification() async {
    if (kIsWeb) return;
    try {
      final p = plan;
      final body = p.isEmpty
          ? 'ยังไม่มีบิลที่ต้องจ่าย'
          : 'ต้องเก็บ ${Money.format(p.dailyRequiredSatang)} วันนี้ '
              'เหลืออีก ${p.daysToEarliestDue} วันถึงบิลแรก';
      await _notifications.rescheduleDaily(
        enabled: notificationsEnabled,
        time: reminderTime,
        body: body,
      );
    } catch (_) {
      // แจ้งเตือนล้มเหลวต้องไม่ไปขึ้นข้อความ error ในหน้าแอพ
    }
  }

  Future<void> _commit() async {
    await _pushToCloud();
    await _refreshNotification();
    notifyListeners();
  }

  Future<void> _pushToCloud() async {
    if (!syncEnabled || !_sync.isConfigured) return;
    try {
      await _sync.push(
        bills: _bills,
        entries: _entries,
        settings: _settings,
      );
    } catch (_) {
      // ซิงก์ล้มเหลวไม่ควรบล็อกการใช้งานแบบ local-first
    }
  }

  void _replaceBills(List<Bill> updated) {
    final map = {for (final b in updated) b.id: b};
    _bills = _bills.map((b) => map[b.id] ?? b).toList();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }
}
