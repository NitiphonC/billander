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
import '../services/update_service.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_'
    '${Random().nextInt(1 << 30).toRadixString(36)}';

enum PaymentResult { success, insufficient, notFound }

class AppState extends ChangeNotifier {
  AppState({AppStorage? storage}) : _db = storage ?? AppStorage.create();

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
        defaultSaveAheadMonths: defaultSaveAheadMonths,
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

  String get updateUrl => _settings[settingUpdateUrl] ?? '';

  /// ค่าตั้งต้น: เก็บล่วงหน้าได้ไม่เกินกี่เดือน (บิลที่ระบุเองจะ override)
  int get defaultSaveAheadMonths {
    final value = int.tryParse(
            _settings[settingDefaultSaveAheadMonths] ?? '') ??
        1;
    return value < 1 ? 1 : value;
  }

  /// ข้อความ error ที่โชว์ผู้ใช้ได้ (ไม่โชว์ technical exception)
  String? get userError => error == null ? null : 'เกิดปัญหาเล็กน้อย — ข้อมูลในเครื่องยังปลอดภัย';

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
      await _db.init();

      _settings.clear();
      _settings.addAll(await _db.getAllSettings());

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

  /// วันที่ของรอบที่ [index] (0 = รอบแรก) ตามความถี่ที่เลือก
  DateTime occurrenceDate(
    DateTime anchor,
    RepeatUnit unit,
    int every,
    int index,
  ) {
    final step = every < 1 ? 1 : every;
    switch (unit) {
      case RepeatUnit.week:
        return dateOnly(anchor.add(Duration(days: 7 * step * index)));
      case RepeatUnit.month:
        return addMonthsClamped(anchor, step * index);
      case RepeatUnit.none:
        return anchor;
    }
  }

  Future<void> _materializeRecurring() async {
    final horizon = _today.add(const Duration(days: 365));
    final groups = <String, List<Bill>>{};
    for (final bill in _bills) {
      final seriesId = bill.seriesId;
      if (bill.isRecurring && seriesId != null) {
        (groups[seriesId] ??= <Bill>[]).add(bill);
      }
    }

    for (final group in groups.entries) {
      final members = group.value
        ..sort((a, b) => a.occurrenceIndex.compareTo(b.occurrenceIndex));
      var anchor = members.first;
      final unit = anchor.repeatUnit;
      final every = anchor.repeatEvery < 1 ? 1 : anchor.repeatEvery;
      final now = DateTime.now().millisecondsSinceEpoch;

      // ข้อมูลเวอร์ชันเก่าทุกตัวมี occurrence_index = 0 → คำนวณลำดับใหม่จากวันที่
      if (members.map((b) => b.occurrenceIndex).toSet().length !=
          members.length) {
        final fixed = <Bill>[];
        for (final bill in members) {
          final index = unit == RepeatUnit.week
              ? bill.dueDate.difference(anchor.dueDate).inDays ~/ (7 * every)
              : (monthIndex(bill.dueDate) - monthIndex(anchor.dueDate)) ~/ every;
          final next = bill.copyWith(
            occurrenceIndex: index < 0 ? 0 : index,
            repeatUnit: unit,
            repeatEvery: every,
            repeatTimes: anchor.repeatTimes,
            updatedAtMs: now,
          );
          await _db.upsertBill(next);
          fixed.add(next);
        }
        _replaceBills(fixed);
        members
          ..clear()
          ..addAll(fixed)
          ..sort((a, b) => a.occurrenceIndex.compareTo(b.occurrenceIndex));
        anchor = members.first;
      }

      final maxIndex = anchor.repeatTimes == null
          ? 300
          : anchor.repeatTimes! - 1;
      var index = 0;
      while (index <= maxIndex && index < 300) {
        final date = occurrenceDate(anchor.dueDate, unit, every, index);
        if (anchor.repeatTimes == null && date.isAfter(horizon)) break;
        if (!members.any((b) => b.occurrenceIndex == index)) {
          final created = Bill(
            id: newId(),
            title: anchor.title,
            amountSatang: anchor.amountSatang,
            dueDate: date,
            repeatUnit: unit,
            repeatEvery: every,
            repeatTimes: anchor.repeatTimes,
            occurrenceIndex: index,
            saveAheadMonths: anchor.saveAheadMonths,
            seriesId: group.key,
            createdAtMs: now,
            updatedAtMs: now,
          );
          await _db.upsertBill(created);
          _bills = [..._bills, created];
          members.add(created);
        }
        index++;
      }
    }
  }

  Future<void> addBill({
    required String title,
    required int amountSatang,
    required DateTime dueDate,
    required RepeatUnit repeatUnit,
    required int repeatEvery,
    int? repeatTimes,
    int? saveAheadMonths,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId();
    final bill = Bill(
      id: id,
      title: title.trim(),
      amountSatang: amountSatang.abs(),
      dueDate: dateOnly(dueDate),
      repeatUnit: repeatUnit,
      repeatEvery: repeatEvery < 1 ? 1 : repeatEvery,
      repeatTimes: repeatTimes,
      occurrenceIndex: 0,
      saveAheadMonths:
          saveAheadMonths != null && saveAheadMonths < 1 ? 1 : saveAheadMonths,
      seriesId: repeatUnit == RepeatUnit.none ? null : id,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.upsertBill(bill);
    _bills = [..._bills, bill];
    if (repeatUnit != RepeatUnit.none) await _materializeRecurring();
    await _commit();
  }

  Future<void> updateBill({
    required String billId,
    required String title,
    required int amountSatang,
    required DateTime dueDate,
    required RepeatUnit repeatUnit,
    required int repeatEvery,
    int? repeatTimes,
    int? saveAheadMonths,
    required bool applyToFuture,
  }) async {
    final original = billById(billId);
    if (original == null) return;
    final every = repeatEvery < 1 ? 1 : repeatEvery;
    final now = DateTime.now().millisecondsSinceEpoch;

    // เปลี่ยนจากซ้ำ → ไม่ซ้ำ: ลบรอบในอนาคตที่ยังไม่จ่ายออก
    if (original.isRecurring && repeatUnit == RepeatUnit.none) {
      final futureIds = _bills
          .where((b) =>
              b.seriesId == original.seriesId &&
              !b.isPaid &&
              b.occurrenceIndex > original.occurrenceIndex)
          .map((b) => b.id)
          .toList();
      if (futureIds.isNotEmpty) {
        await _db.deleteBills(futureIds);
        _bills = _bills.where((b) => !futureIds.contains(b.id)).toList();
      }
    }

    final shouldUpdateSeries =
        (repeatUnit != RepeatUnit.none || applyToFuture) &&
            original.seriesId != null &&
            repeatUnit != RepeatUnit.none;
    final targets = shouldUpdateSeries
        ? _bills
            .where((b) =>
                b.seriesId == original.seriesId && !b.isPaid)
            .toList()
        : <Bill>[original];

    final newAnchorDate = dateOnly(dueDate);
    final updated = <Bill>[];
    for (final target in targets) {
      final indexDelta = target.occurrenceIndex - original.occurrenceIndex;
      final next = target.copyWith(
        title: title.trim(),
        amountSatang: amountSatang.abs(),
        dueDate: shouldUpdateSeries
            ? occurrenceDate(newAnchorDate, repeatUnit, every, indexDelta)
            : newAnchorDate,
        repeatUnit: repeatUnit,
        repeatEvery: every,
        repeatTimes: repeatTimes,
        clearRepeatTimes: repeatTimes == null,
        occurrenceIndex: shouldUpdateSeries ? target.occurrenceIndex : 0,
        saveAheadMonths:
            saveAheadMonths != null && saveAheadMonths < 1 ? 1 : saveAheadMonths,
        clearSaveAheadMonths: saveAheadMonths == null,
        clearSeriesId: repeatUnit == RepeatUnit.none,
        updatedAtMs: now,
      );
      await _db.upsertBill(next);
      updated.add(next);
    }
    _replaceBills(updated);
    if (repeatUnit != RepeatUnit.none) await _materializeRecurring();
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
              b.occurrenceIndex >= bill.occurrenceIndex &&
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
    notifyListeners();
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
    await _refreshNotification();
    notifyListeners();
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
