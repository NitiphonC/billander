import 'package:billandar/core/calculator.dart';
import 'package:billandar/core/money.dart';
import 'package:billandar/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

Bill makeBill(
  String id,
  int amountBaht,
  DateTime dueDate, {
  DateTime? paidAt,
  int createdAtMs = 1,
}) =>
    Bill(
      id: id,
      title: 'บิล $id',
      amountSatang: Money.fromBaht(amountBaht.toDouble()),
      dueDate: dueDate,
      paidAt: paidAt,
      createdAtMs: createdAtMs,
      updatedAtMs: createdAtMs,
    );

void main() {
  final nov1 = DateTime(2026, 11, 1);
  final nov2 = DateTime(2026, 11, 2);
  final nov5 = DateTime(2026, 11, 5);
  final nov9 = DateTime(2026, 11, 9);
  final nov10 = DateTime(2026, 11, 10);
  final nov12 = DateTime(2026, 11, 12);
  final nov20 = DateTime(2026, 11, 20);
  final dec2 = DateTime(2026, 12, 2);

  group('CAL — สูตรคำนวณหลัก', () {
    test('CAL-01 ตัวอย่างผู้ใช้ 15/วัน', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10), makeBill('B', 100, nov20)],
        poolSatang: 0,
        today: nov1,
      );
      expect(plan.bills[0].daysRemaining, 10);
      expect(plan.bills[0].perDaySatang, 1000);
      expect(plan.bills[1].daysRemaining, 20);
      expect(plan.bills[1].perDaySatang, 500);
      expect(plan.dailyRequiredSatang, 1500);
      expect(Money.format(plan.dailyRequiredSatang), '฿15.00');
    });

    test('CAL-02 วันนี้เป็นวันจ่าย n=1', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov1)],
        poolSatang: 0,
        today: nov1,
      );
      expect(plan.bills.single.daysRemaining, 1);
      expect(plan.bills.single.perDaySatang, 10000);
    });

    test('CAL-03 วันติดกัน n=2', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov2)],
        poolSatang: 0,
        today: nov1,
      );
      expect(plan.bills.single.daysRemaining, 2);
      expect(plan.bills.single.perDaySatang, 5000);
    });

    test('CAL-04 ข้ามเดือน 30 พ.ย. → 2 ธ.ค. เป็น 3 วัน', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, dec2)],
        poolSatang: 0,
        today: DateTime(2026, 11, 30),
      );
      expect(plan.bills.single.daysRemaining, 3);
      expect(plan.bills.single.perDaySatang, 3334);
    });

    test('CAL-05 เรียงตามวันจ่ายแม้ใส่ลำดับกลับ', () {
      final plan = Calculator.calculate(
        bills: [
          makeBill('B', 100, nov20, createdAtMs: 1),
          makeBill('A', 100, nov10, createdAtMs: 2),
        ],
        poolSatang: 15000,
        today: nov1,
      );
      expect(plan.bills.first.bill.id, 'A');
      expect(plan.bills.first.coveredByPoolSatang, 10000);
      expect(plan.bills.last.bill.id, 'B');
      expect(plan.bills.last.coveredByPoolSatang, 5000);
    });

    test('CAL-06 คลังหักบิลแรกจนหมด', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10), makeBill('B', 300, nov20)],
        poolSatang: Money.fromBaht(100),
        today: nov1,
      );
      expect(plan.bills[0].coveredByPoolSatang, 10000);
      expect(plan.bills[0].perDaySatang, 0);
      expect(plan.bills[1].coveredByPoolSatang, 0);
      expect(plan.bills[1].perDaySatang, 1500);
      expect(plan.dailyRequiredSatang, 1500);
    });

    test('CAL-07 คลังหักบิลแรกบางส่วน', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10), makeBill('B', 100, nov20)],
        poolSatang: Money.fromBaht(50),
        today: nov1,
      );
      expect(plan.bills[0].coveredByPoolSatang, 5000);
      expect(plan.bills[0].perDaySatang, 500);
      expect(plan.bills[1].coveredByPoolSatang, 0);
      expect(plan.bills[1].perDaySatang, 500);
      expect(plan.dailyRequiredSatang, 1000);
    });

    test('CAL-08 คลังมากกว่ายอดรวม → ไม่ต้องเก็บ', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10), makeBill('B', 100, nov20)],
        poolSatang: Money.fromBaht(500),
        today: nov1,
      );
      expect(plan.isFullyCovered, isTrue);
      expect(plan.coveredByPoolSatang, 20000);
      expect(plan.dailyRequiredSatang, 0);
      expect(plan.stillToSaveSatang, 0);
    });

    test('CAL-09 คลังติดลบถูก clamp เป็น 0', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: -10000,
        today: nov1,
      );
      expect(plan.dailyRequiredSatang, 1000);
      expect(plan.coveredByPoolSatang, 0);
    });

    test('CAL-10 ปัดขึ้นเศษสตางค์', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 0,
        today: nov5,
      );
      expect(plan.bills.single.daysRemaining, 6);
      expect(plan.bills.single.perDaySatang, 1667);
    });

    test('CAL-11 บิลเลยกำหนด 2 วัน', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 0,
        today: nov12,
      );
      expect(plan.bills.single.isOverdue, isTrue);
      expect(plan.bills.single.daysOverdue, 2);
      expect(plan.bills.single.daysRemaining, 1);
      expect(plan.bills.single.perDaySatang, 10000);
      expect(plan.overdueCount, 1);
    });

    test('CAL-12 เลยกำหนดหลายบิล', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov9), makeBill('B', 50, nov10)],
        poolSatang: 0,
        today: nov12,
      );
      expect(plan.overdueCount, 2);
      expect(plan.dailyRequiredSatang, 15000);
    });

    test('CAL-13 วันผ่านไปโดยไม่บันทึก → ยอดต่อวันเพิ่ม', () {
      final before = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 0,
        today: nov1,
      );
      final after = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 0,
        today: nov5,
      );
      expect(before.bills.single.perDaySatang, 1000);
      expect(after.bills.single.perDaySatang, 1667);
      expect(after.bills.single.perDaySatang,
          greaterThan(before.bills.single.perDaySatang));
    });

    test('CAL-14 จ่ายบิลแล้วตัดออก', () {
      final plan = Calculator.calculate(
        bills: [
          makeBill('A', 100, nov10, paidAt: DateTime(2026, 11, 10)),
          makeBill('B', 100, nov20),
        ],
        poolSatang: 0,
        today: nov10,
      );
      expect(plan.bills.length, 1);
      expect(plan.bills.single.bill.id, 'B');
      expect(plan.bills.single.daysRemaining, 11);
      expect(plan.bills.single.perDaySatang, 910);
    });

    test('CAL-15 กดจ่ายได้เฉพาะคลังพอ', () {
      expect(
          Calculator.canPay(poolSatang: 10000, billAmountSatang: 10000), isTrue);
      expect(
          Calculator.canPay(poolSatang: 9999, billAmountSatang: 10000), isFalse);
      expect(Calculator.canPay(poolSatang: 0, billAmountSatang: 0), isTrue);
    });

    test('CAL-16 ไม่มีบิล', () {
      final plan = Calculator.calculate(
        bills: const [],
        poolSatang: 5000,
        today: nov1,
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.dailyRequiredSatang, 0);
      expect(plan.note, isNotNull);
      expect(plan.daysToEarliestDue, 0);
    });

    test('CAL-17 progress อยู่ในช่วง 0–1', () {
      for (final pool in [-100, 0, 5000, 10000, 50000]) {
        final plan = Calculator.calculate(
          bills: [makeBill('A', 100, nov10)],
          poolSatang: pool,
          today: nov1,
        );
        expect(plan.progress, inInclusiveRange(0, 1));
      }
    });

    test('CAL-18 daysToEarliestDue นับรวมวันนี้', () {
      final plan = Calculator.calculate(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 0,
        today: nov1,
      );
      expect(plan.daysToEarliestDue, 10);
    });
  });

  group('PROJ — ตารางแนะนำรายวัน', () {
    test('PROJ-19 วันแรกได้ 15 บาท', () {
      final p = Calculator.project(
        bills: [makeBill('A', 100, nov10), makeBill('B', 100, nov20)],
        poolSatang: 0,
        today: nov1,
      );
      expect(p.first.requiredSatang, 1500);
      expect(p.length, 20);
    });

    test('PROJ-20 วันที่ 10 จ่ายบิล A', () {
      final p = Calculator.project(
        bills: [makeBill('A', 100, nov10), makeBill('B', 100, nov20)],
        poolSatang: 0,
        today: nov1,
      );
      expect(p[9].paidBillTitles, ['บิล A']);
      expect(p[9].date.day, 10);
    });

    test('PROJ-21 ไม่มีบิล → คืนรายการว่าง', () {
      final p = Calculator.project(
        bills: const [],
        poolSatang: 0,
        today: nov1,
      );
      expect(p, isEmpty);
    });

    test('PROJ-22 maxDays จำกัดจำนวนวัน', () {
      final far = nov1.add(const Duration(days: 90));
      final p = Calculator.project(
        bills: [makeBill('A', 100, far)],
        poolSatang: 0,
        today: nov1,
        maxDays: 5,
      );
      expect(p.length, 5);
    });

    test('PROJ-23 คลังพออยู่แล้ว → ทุกวันไม่ต้องเก็บ', () {
      final p = Calculator.project(
        bills: [makeBill('A', 100, nov10)],
        poolSatang: 100000,
        today: nov1,
      );
      expect(p.every((d) => d.requiredSatang == 0), isTrue);
      expect(p.last.paidBillTitles, ['บิล A']);
    });
  });

  group('MONEY — เฮลเปอร์เงิน', () {
    test('ceilDiv ปัดขึ้น', () {
      expect(Money.ceilDiv(10000, 6), 1667);
      expect(Money.ceilDiv(0, 6), 0);
      expect(Money.ceilDiv(100, 3), 34);
      expect(Money.ceilDiv(10, 10), 1);
    });

    test('fromBaht / toBaht', () {
      expect(Money.fromBaht(12.34), 1234);
      expect(Money.toBaht(1234), 12.34);
    });
  });
}
