import 'package:billandar/core/app_config.dart';
import 'package:billandar/core/calculator.dart';
import 'package:billandar/core/money.dart';
import 'package:billandar/data/database.dart';
import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/models/ledger_entry.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:billandar/ui/calendar_screen.dart';
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

  test('SET-14 ปรับเงินในคลัง → ตัวเลขตรงกับที่ตั้ง และไม่ลบรายการเดิม', () async {
    final s = await state();
    await s.recordDeposit(50000);
    await s.recordWithdrawal(20000);
    expect(s.poolSatang, 30000);
    final entriesBefore = s.entries.length;

    await s.setPoolBalance(150000);

    expect(s.poolSatang, 150000);
    expect(s.entries.length, entriesBefore);
    expect(s.entries.where((e) => e.type == LedgerType.deposit).length, 1);
    expect(s.entries.where((e) => e.type == LedgerType.withdrawal).length, 1);
  });

  test('SET-15 ปรับคลังแล้วเปิดแอพใหม่ → ยอดยังเท่าเดิม', () async {
    final first = await state();
    await first.setPoolBalance(123456);
    final second = await state();
    expect(second.poolSatang, 123456);
  });

  test('SET-16 ปรับคลังให้พอจ่ายบิล → dailyRequired เป็น 0', () async {
    final s = await state();
    await s.addBill(
      title: 'ค่าเช่า',
      amountSatang: 50000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    // วันนี้ 23 → จ่าย 24 = 2 วัน (รวมวันนี้) → 50000/2 = 25000/วัน
    expect(s.plan.dailyRequiredSatang, 25000);

    await s.setPoolBalance(50000);

    expect(s.plan.dailyRequiredSatang, 0);
    expect(s.plan.isFullyCovered, isTrue);
  });

  test('SET-18 หน่วยวัน: ลิมิต 10 วัน', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '10');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.days.name);
    expect(s.defaultSaveAheadUnit, SaveAheadUnit.days);

    await s.addBill(
      title: 'ใกล้',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 5)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    await s.addBill(
      title: 'ไกล',
      amountSatang: 20000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 20)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(s.plan.bills.length, 1);
    expect(s.plan.bills.single.bill.title, 'ใกล้');
    expect(s.plan.excludedCount, 1);
  });

  test('SET-19 หน่วยปี: ลิมิต 1 ปีครอบบิล 6 เดือน', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.years.name);
    await s.addBill(
      title: 'ครึ่งปี',
      amountSatang: 100000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 180)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    expect(s.plan.bills.length, 1);
  });

  test('SET-20 ลิมิตแยกบิลเป็นวัน แม้ค่าตั้งต้นเป็นเดือน', () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.addBill(
      title: 'บิลแยก',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23).add(const Duration(days: 20)),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 30,
      saveAheadUnit: SaveAheadUnit.days,
    );
    expect(s.plan.bills.length, 1);
  });

  test('SET-21 หน่วยของลิมิตแยกบิลอยู่รอดหลัง reload', () async {
    final first = await state();
    await first.addBill(
      title: 'บิลแยก',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 2,
      saveAheadUnit: SaveAheadUnit.years,
    );
    final second = await state();
    expect(second.bills.single.saveAheadMonths, 2);
    expect(second.bills.single.saveAheadUnit, SaveAheadUnit.years);
  });

  test('SET-22 ลิมิต 1 วัน = เฉพาะวันจ่าย (วันจ่ายนับเป็น 1 วันในลิมิต)',
      () async {
    final s = await state();
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.days.name);
    await s.addBill(
      title: 'พรุ่งนี้จ่าย',
      amountSatang: 20000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );

    // วันที่ 23 → ยังไม่เข้า (limit 1 → horizon = 23)
    expect(s.plan.bills, isEmpty);

    // วันที่ 24 = วันจ่าย → เข้า นับ 1 วัน เก็บเต็มยอด
    final dueDay = Calculator.calculate(
      bills: s.bills,
      poolSatang: s.poolSatang,
      today: DateTime(2026, 11, 24),
      defaultSaveAheadMonths: 1,
      defaultSaveAheadUnit: SaveAheadUnit.days,
    );
    expect(dueDay.bills.length, 1);
    expect(dueDay.bills.single.daysRemaining, 1);
    expect(dueDay.bills.single.perDaySatang, 20000);
  });

  test('SET-23 ลิมิต 7 วัน = วันจ่าย + อีก 6 วัน (ตั้ง 7 ได้ 7 วันพอดี)',
      () async {
    final s = await state();
    await s.addBill(
      title: 'อีก 7 วันจ่าย',
      amountSatang: 70000,
      dueDate: DateTime(2026, 11, 30),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );

    // วันที่ 23 → horizon = 29 → ยังไม่เข้า
    final far = Calculator.calculate(
      bills: s.bills,
      poolSatang: s.poolSatang,
      today: DateTime(2026, 11, 23),
      defaultSaveAheadMonths: 7,
      defaultSaveAheadUnit: SaveAheadUnit.days,
    );
    expect(far.bills, isEmpty);

    // วันที่ 24 → เข้าช่วง วันที่ 24..30 = 7 วัน
    final near = Calculator.calculate(
      bills: s.bills,
      poolSatang: s.poolSatang,
      today: DateTime(2026, 11, 24),
      defaultSaveAheadMonths: 7,
      defaultSaveAheadUnit: SaveAheadUnit.days,
    );
    expect(near.bills.length, 1);
    expect(near.bills.single.daysRemaining, 7);
    expect(near.bills.single.perDaySatang, 10000);
  });

  testWidgets('SET-24 แท็บบิลโชว์ลิมิตและจำนวนวันที่เหลือ', (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.days.name);
    await s.addBill(
      title: 'บิลทดสอบ',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );

    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => BillsScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('เก็บล่วงหน้า 1 วัน'), findsOneWidget);
    expect(find.textContaining('เหลืออีก 2 วัน'), findsOneWidget);
  });

  test('SET-26 ไอคอนบิล (ตัวอักษร/สี/ภาพวาด) อยู่รอดหลัง reload', () async {
    final first = await state();
    await first.addBill(
      title: 'ค่าเช่า',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      iconText: 'ร',
      iconColor: 0xFFD32F2F,
      iconDrawing: 'aW1hZ2U=',
    );
    final second = await state();
    final bill = second.bills.single;
    expect(bill.iconText, 'ร');
    expect(bill.iconColor, 0xFFD32F2F);
    expect(bill.iconDrawing, 'aW1hZ2U=');
  });

  testWidgets('SET-27 แท็บบิลโชว์ตัวอักษรในไอคอน', (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await s.addBill(
      title: 'ค่าเช่า',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 24),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      iconText: 'ร',
      iconColor: 0xFFD32F2F,
    );
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => BillsScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ร'), findsWidgets);
  });

  testWidgets('SET-25 ปฏิทินโชว์ยอดบิลที่ต้องจ่ายในวันนั้น', (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.days.name);
    await s.addBill(
      title: 'บิลวันนี้',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: s,
          builder: (_, __) => CalendarScreen(state: s),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // ลิมิต 1 วัน + คลัง 0 → วันจ่ายคือวันเก็บ → โชว์แค่ "ยอดที่ต้องเก็บ" ฿100
    expect(find.text('฿100.00'), findsWidgets);
    expect(find.text('฿200.00'), findsNothing);

    // ถ้าเก็บครบแล้ว → ยอดที่ต้องเก็บวันนั้นเป็น 0
    await s.setPoolBalance(10000);
    await tester.pumpAndSettle();
    // เก็บครบแล้ว → ไม่ต้องเก็บเพิ่ม เซลล์ไม่โชว์ยอดเก็บอีก
    expect(find.text('฿100.00'), findsNothing);
  });

  testWidgets('SET-17 หน้าตั้งค่าโชว์ยอดคลังตัวเดียวกับหน้าภาพรวม',
      (tester) async {
    final s = await state();
    addTearDown(s.dispose);
    await s.recordDeposit(75000);

    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => SettingsScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(Money.format(s.poolSatang)), findsOneWidget);
    expect(find.text('ปรับเงินในคลัง'), findsOneWidget);
    expect(find.textContaining('ปรับเงินตั้งต้น'), findsNothing);
  });
}

int ceilDivLocal(int amount, int days) =>
    (amount + days - 1) ~/ days;
