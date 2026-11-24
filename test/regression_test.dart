import 'package:billandar/core/calculator.dart';
import 'package:billandar/core/date_utils.dart';
import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/models/ledger_entry.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> freshState() async {
    final s = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await s.load();
    return s;
  }

  Bill billWith({
    required String title,
    required int amount,
    required DateTime due,
    int? saveAhead,
    SaveAheadUnit? unit,
  }) =>
      Bill(
        id: title,
        title: title,
        amountSatang: amount,
        dueDate: due,
        repeatUnit: RepeatUnit.none,
        repeatEvery: 1,
        repeatTimes: null,
        saveAheadMonths: saveAhead,
        saveAheadUnit: unit,
        createdAtMs: 1,
        updatedAtMs: 1,
      );

  group('REG — override inheritance', () {
    test('REG-01 value override แต่ unit null → ใช้ months แบบเดิม (legacy)',
        () {
      final plan = Calculator.calculate(
        bills: [
          billWith(
            title: 'legacy',
            amount: 10000,
            due: DateTime(2026, 11, 29),
            saveAhead: 7,
          ),
        ],
        poolSatang: 0,
        today: DateTime(2026, 11, 23),
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.days,
      );
      expect(plan.bills.length, 1);
    });

    test('REG-02 ไม่มี override เลย → ใช้ unit ของค่าตั้งต้นทั้ง 2 ทาง', () {
      final b = billWith(
        title: 'default',
        amount: 10000,
        due: DateTime(2026, 11, 29),
      );
      final asMonths = Calculator.calculate(
        bills: [b],
        poolSatang: 0,
        today: DateTime(2026, 11, 23),
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.months,
      );
      final asDays = Calculator.calculate(
        bills: [b],
        poolSatang: 0,
        today: DateTime(2026, 11, 23),
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.days,
      );
      expect(asMonths.bills.length, 1);
      expect(asDays.bills, isEmpty);
    });
  });

  group('REG — calendar projection', () {
    test('REG-03 บิลเลยกำหนดไม่โชว์ยอดเก็บซ้ำในปฏิทิน', () {
      final projection = Calculator.project(
        bills: [
          billWith(
              title: 'เก่า',
              amount: 10000,
              due: DateTime(2026, 11, 24)),
          billWith(
              title: 'ใหม่',
              amount: 20000,
              due: DateTime(2026, 11, 30)),
        ],
        poolSatang: 0,
        today: DateTime(2026, 11, 26),
        maxDays: 5,
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.days,
        simulateFutureSavings: false,
      );
      // วันนี้ (26) ให้โชว์บิลเลยกำหนดเป็นยอดกู้คืน (ตรงภาพรวม)
      expect(projection.first.contributions.map((c) => c.title), contains('เก่า'));
      // แต่วันถัดไปห้ามโชว์ซ้ำ
      for (final day in projection.skip(1)) {
        expect(day.contributions.map((c) => c.title), isNot(contains('เก่า')));
      }
      for (final day in projection) {
        expect(day.paidBillTitles, isEmpty);
      }
      final day30 = projection.firstWhere(
          (d) => dateKey(d.date) == '2026-11-30',
          orElse: () => projection.last);
      expect(day30.requiredSatang, 20000);
    });

    test('REG-04 ปฏิทินหักคลังจริง แต่ไม่สะสมเงินสมมติ', () {
      final projection = Calculator.project(
        bills: [
          billWith(
            title: 'ใกล้',
            amount: 10000,
            due: DateTime(2026, 11, 23),
          ),
          billWith(
            title: 'ไกล',
            amount: 10000,
            due: DateTime(2026, 11, 29),
            saveAhead: 7,
            unit: SaveAheadUnit.days,
          ),
        ],
        poolSatang: 6000,
        today: DateTime(2026, 11, 23),
        maxDays: 8,
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.days,
        simulateFutureSavings: false,
      );
      final byDate = {for (final d in projection) dateKey(d.date): d};
      // คลังจริง 60 บาทหักบิลใกล้ (เหลือ 40) + บิลไกล 100/7 = 14.29
      expect(byDate['2026-11-23']!.requiredSatang, 5429);
      // วันถัดมาไม่ได้เอาเงินที่ "จำลองเก็บ" ไปหัก → ยังต้องเก็บเต็มตามสูตร
      expect(byDate['2026-11-24']!.requiredSatang, 1667);
    });
  });

  group('REG — validation & display', () {
    test('REG-06 ยอดติดลบ/ศูนย์จากข้อมูลเสียถูก clamp', () {
      final b = Bill.fromMap({
        'id': 'bad',
        'title': 'เสีย',
        'amount': -5000,
        'due_date': '2026-11-29',
        'repeat_unit': 'none',
        'repeat_every': 1,
        'occurrence_index': 0,
        'created_at': 1,
        'updated_at': 1,
      });
      expect(b.amountSatang, 5000);
    });

    testWidgets('REG-07 บิลเลยกำหนดโชว์ "เลยกำหนด N วัน" ไม่ใช่ "เหลืออีก 1 วัน"',
        (tester) async {
      final s = await freshState();
      await s.addBill(
        title: 'เก่า',
        amountSatang: 10000,
        dueDate: DateTime(2026, 10, 1),
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
      expect(find.textContaining('เลยกำหนด 53 วัน'), findsOneWidget);
      expect(find.textContaining('เหลืออีก 1 วัน'), findsNothing);
      addTearDown(s.dispose);
    });
  });

  group('REG — shared vault', () {
    test('REG-05 แก้คลังไม่ลบรายการจ่ายที่ Existing อยู่', () async {
      final s = await freshState();
      await s.recordDeposit(50000);
      await s.addBill(
        title: 'จ่ายแล้ว',
        amountSatang: 20000,
        dueDate: DateTime(2026, 11, 23),
        repeatUnit: RepeatUnit.none,
        repeatEvery: 1,
        repeatTimes: null,
      );
      final bill = s.bills.single;
      expect(await s.markPaid(bill.id), PaymentResult.success);

      final before = s.entries.length;
      final payment = s.entries.firstWhere((e) => e.type == LedgerType.payment);
      await s.setPoolBalance(100000);

      expect(s.entries.length, before);
      final after = s.entries.firstWhere((e) => e.id == payment.id);
      expect(after.amountSatang, -20000);
      expect(after.billId, bill.id);
      expect(s.poolSatang, 100000);
    });
  });
}
