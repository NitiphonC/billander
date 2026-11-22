import 'package:billandar/core/app_config.dart';
import 'package:billandar/core/date_utils.dart';
import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> freshState() async {
    final state = AppState(storage: WebStorage());
    await state.load();
    return state;
  }

  test('REC-01 ทุกสัปดาห์ 5 รอบ → สร้างครบ 5 วันห่างกัน 7 วัน', () async {
    final state = await freshState();
    await state.addBill(
      title: 'ค่าผ่อน',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.week,
      repeatEvery: 1,
      repeatTimes: 5,
    );

    final bills = state.bills.where((b) => b.seriesId != null).toList();
    expect(bills.length, 5);
    final dates = bills.map((b) => dateKey(b.dueDate)).toList()..sort();
    expect(dates, [
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
      '2026-12-14',
      '2026-12-21',
    ]);
    expect(bills.map((b) => b.occurrenceIndex).toSet(), {0, 1, 2, 3, 4});
  });

  test('REC-02 ทุก 2 เดือน 3 รอบ → 23 พ.ย., 23 ม.ค., 23 มี.ค.', () async {
    final state = await freshState();
    await state.addBill(
      title: 'ประกัน',
      amountSatang: 50000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.month,
      repeatEvery: 2,
      repeatTimes: 3,
    );

    final dates = state.bills
        .where((b) => b.seriesId != null)
        .map((b) => dateKey(b.dueDate))
        .toList()
      ..sort();
    expect(dates, [
      '2026-11-23',
      '2027-01-23',
      '2027-03-23',
    ]);
  });

  test('REC-03 ไม่ซ้ำ → ไม่มีการสร้างรอบเพิ่ม', () async {
    final state = await freshState();
    await state.addBill(
      title: 'จ่ายครั้งเดียว',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 25),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(state.bills.length, 1);
    expect(state.bills.single.seriesId, isNull);
  });

  test('REC-04 เปลี่ยนจากซ้ำเป็นไม่ซ้ำ → ลบรอบในอนาคตออก', () async {
    final state = await freshState();
    await state.addBill(
      title: 'ผ่อน',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.week,
      repeatEvery: 1,
      repeatTimes: 4,
    );
    expect(state.bills.length, 4);

    final anchor = state.bills.firstWhere((b) => b.occurrenceIndex == 0);
    await state.updateBill(
      billId: anchor.id,
      title: 'ผ่อน',
      amountSatang: 10000,
      dueDate: anchor.dueDate,
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      applyToFuture: false,
    );
    expect(state.bills.length, 1);
  });

  test('REC-05 ลิมิตตั้งต้น 1 เดือน → บิลอีก 3 เดือนยังไม่เข้าคำนวณ', () async {
    final state = await freshState();
    await state.addBill(
      title: 'บิลไกล',
      amountSatang: 300000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 90)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(state.plan.bills, isEmpty);
    expect(state.plan.excludedCount, 1);
    expect(state.plan.dailyRequiredSatang, 0);
  });

  test('REC-06 ตั้งแยกบิล 3 เดือน → บิลเดิมเข้าคำนวณ', () async {
    final state = await freshState();
    await state.addBill(
      title: 'หนี้ก้อนใหญ่',
      amountSatang: 300000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 90)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 3,
    );
    expect(state.plan.bills.length, 1);
    expect(state.plan.excludedCount, 0);
    expect(state.plan.dailyRequiredSatang, greaterThan(0));
  });

  test('REC-07 เปลี่ยนค่าตั้งต้นเป็น 4 เดือน → บิล 3 เดือนเข้าคำนวณ', () async {
    final state = await freshState();
    await state.updateSetting(settingDefaultSaveAheadMonths, '4');
    await state.addBill(
      title: 'บิลไกล',
      amountSatang: 100000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 90)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(state.defaultSaveAheadMonths, 4);
    expect(state.plan.bills.length, 1);
  });
}
