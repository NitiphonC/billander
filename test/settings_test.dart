import 'package:billandar/core/app_config.dart';
import 'package:billandar/data/database.dart';
import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:billandar/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> state({AppStorage? storage}) async {
    final s = AppState(storage: storage ?? WebStorage());
    await s.load();
    return s;
  }

  test('SET-01 ค่าตั้งต้นเริ่มต้นเป็น 1 เดือน', () async {
    final s = await state();
    expect(s.defaultSaveAheadMonths, 1);
  });

  test('SET-02 updateSetting แล้ว getter ต้องเปลี่ยนทันที', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '3');
    expect(s.defaultSaveAheadMonths, 3);
  });

  test('SET-03 ค่าที่ตั้งไว้ต้องอยู่รอดเมื่อ storage ถูกโหลดใหม่ (app restart)',
      () async {
    final first = await state();
    await first.updateSetting(settingDefaultSaveAheadMonths, '3');
    await first.updateSetting(settingNotifications, 'false');

    // AppState ตัวใหม่ + WebStorage ตัวใหม่ = เหมือนเปิดแอพใหม่
    final second = await state();
    expect(second.defaultSaveAheadMonths, 3);
    expect(second.notificationsEnabled, isFalse);
  });

  test('SET-04 แก้ลิมิตต้องไม่ไปลบ setting อื่น', () async {
    final s = await state();
    await s.updateSetting(settingUpdateUrl, 'https://example.com/update.json');
    await s.updateSetting(settingReminderHour, '9');
    await s.updateSetting(settingDefaultSaveAheadMonths, '4');

    expect(s.updateUrl, 'https://example.com/update.json');
    expect(s.reminderTime.hour, 9);
    expect(s.defaultSaveAheadMonths, 4);
  });

  test('SET-05 checkDayChange (เขียน last_seen_date) ต้องไม่ resetting ลิมิต',
      () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '5');
    await s.checkDayChange();
    expect(s.defaultSaveAheadMonths, 5);
  });

  test('SET-06 ตั้งซ้ำหลายครั้ง ต้องเก็บค่าล่าสุด', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '2');
    await s.updateSetting(settingDefaultSaveAheadMonths, '6');
    await s.updateSetting(settingDefaultSaveAheadMonths, '3');
    expect(s.defaultSaveAheadMonths, 3);
  });

  test('SET-07 ค่า 0 / ติดลบ ต้องถูก clamp เป็น 1', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '0');
    expect(s.defaultSaveAheadMonths, 1);
    await s.updateSetting(settingDefaultSaveAheadMonths, '-2');
    expect(s.defaultSaveAheadMonths, 1);
  });

  test('SET-08 เปลี่ยนลิมิตต้องเปลี่ยนยอดที่ต้องเก็บของบิลไกล', () async {
    final s = await state();
    final far = DateTime(2026, 11, 23).add(const Duration(days: 60));
    await s.addBill(
      title: 'บิลไกล',
      amountSatang: 600000,
      dueDate: far,
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(s.plan.bills, isEmpty); // default 1 เดือน → ยังไม่เข้า

    await s.updateSetting(settingDefaultSaveAheadMonths, '3');
    expect(s.plan.bills.length, 1);
    expect(s.plan.dailyRequiredSatang, greaterThan(0));

    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    expect(s.plan.bills, isEmpty);
    expect(s.plan.dailyRequiredSatang, 0);
  });

  test('SET-09 ลิมิตแยกบิลต้องอยู่รอดหลัง reload', () async {
    final first = await state();
    await first.addBill(
      title: 'หนี้ใหญ่',
      amountSatang: 300000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 60)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 3,
    );
    final bill = first.bills.single;

    final second = await state();
    final restored = second.bills.single;
    expect(restored.id, bill.id);
    expect(restored.saveAheadMonths, 3);
    expect(second.plan.bills.length, 1);
    expect(second.plan.dailyRequiredSatang, greaterThan(0));
  });

  test('SET-10 แก้บิลแล้วเปลี่ยนลิมิตแยก ต้องไม่กระทบค่าตั้งต้น', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '2');
    await s.addBill(
      title: 'บิลธรรมดา',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    final bill = s.bills.single;
    await s.updateBill(
      billId: bill.id,
      title: bill.title,
      amountSatang: bill.amountSatang,
      dueDate: bill.dueDate,
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 4,
      applyToFuture: false,
    );

    expect(s.bills.single.saveAheadMonths, 4);
    expect(s.defaultSaveAheadMonths, 2);
  });

  test('SET-11 วันที่ใน plan ต้องตรงกับลิมิตที่ตั้ง (calendar month)', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '2');
    await s.addBill(
      title: 'บิลสองเดือน',
      amountSatang: 600000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 55)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(s.plan.bills.length, 1);
    expect(s.plan.bills.single.perDaySatang,
        ceilDivLocal(600000, s.plan.bills.single.daysRemaining));
  });

  testWidgets('SET-12 หน้าตั้งค่าโชว์ค่าล่าสุดทันทีหลังเปลี่ยน', (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => SettingsScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('ค่าตั้งต้น: 1 เดือน'), findsOneWidget);

    await s.updateSetting(settingDefaultSaveAheadMonths, '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('ค่าตั้งต้น: 3 เดือน'), findsOneWidget);
  });

  testWidgets('SET-13 ฟอร์มบิลโชว์ค่าแยกบิลและปุ่มกลับไปใช้ค่าตั้งต้น',
      (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await s.updateSetting(settingDefaultSaveAheadMonths, '2');
    await s.addBill(
      title: 'หนี้ใหญ่',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 4,
    );
    final bill = s.bills.single;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => BillEditorSheet.show(ctx, s, bill: bill),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('บิลนี้ใช้ค่าที่ตั้งแยก'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('กลับไปใช้ค่าตั้งต้น'), findsOneWidget);
  });
}

int ceilDivLocal(int amount, int days) =>
    (amount + days - 1) ~/ days;
