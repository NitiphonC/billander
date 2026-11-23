import 'package:billandar/core/calculator.dart';
import 'package:billandar/core/date_utils.dart';
import 'package:billandar/core/money.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/models/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CORE — Money', () {
    test('CORE-01 fromBaht', () {
      expect(Money.fromBaht(12.34), 1234);
      expect(Money.fromBaht(0.1), 10);
      expect(Money.fromBaht(-2.5), -250);
    });

    test('CORE-02 tryParse ลบ comma', () {
      expect(Money.tryParse('1,234.56'), 123456);
      expect(Money.tryParse(' 100 '), 10000);
      expect(Money.tryParse('฿50.00'), 5000);
    });

    test('CORE-03 tryParse ข้อความผิดคืน null', () {
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
    });

    test('CORE-04 tryParse ติดลบ', () {
      expect(Money.tryParse('-5'), -500);
    });

    test('CORE-05 format', () {
      expect(Money.format(123456), '฿1,234.56');
      expect(Money.format(0), '฿0.00');
      expect(Money.format(-500), '-฿5.00');
    });

    test('CORE-06 formatCompact', () {
      expect(Money.formatCompact(10000), '฿100.00');
      expect(Money.formatCompact(2000000), '฿20.0k');
      expect(Money.formatCompact(100000000), '฿1.0ล้าน');
    });
  });

  group('CORE — Date utils', () {
    test('CORE-07 daysInclusive', () {
      expect(daysInclusive(DateTime(2026, 11, 1), DateTime(2026, 11, 10)), 10);
      expect(daysInclusive(DateTime(2026, 11, 1), DateTime(2026, 11, 1)), 1);
    });

    test('CORE-08 daysBetween ติดลบ', () {
      expect(daysBetween(DateTime(2026, 11, 12), DateTime(2026, 11, 10)), -2);
    });

    test('CORE-09 dateKey roundtrip', () {
      final d = DateTime(2026, 11, 22);
      expect(dateKey(d), '2026-11-22');
      expect(tryParseDateKey(dateKey(d)), d);
      expect(tryParseDateKey('ไม่ใช่วันที่'), isNull);
      expect(tryParseDateKey(null), isNull);
    });

    test('CORE-10 addMonthsClamped', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonthsClamped(DateTime(2026, 11, 15), -1),
          DateTime(2026, 10, 15));
    });

    test('CORE-11 daysInMonth ปีอธิกสุรทิน', () {
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2028, 2)), 29);
    });

    test('CORE-12 formatDateThai พ.ศ.', () {
      expect(formatDateThai(DateTime(2026, 11, 22)), '22 พฤศจิกายน 2569');
      expect(monthIndex(DateTime(2026, 1)), 2026 * 12);
    });
  });

  group('CORE — Model roundtrip', () {
    test('CORE-13 Bill', () {
      final bill = Bill(
        id: 'id-1',
        title: 'ค่าเช่า',
        amountSatang: 850000,
        dueDate: DateTime(2026, 12, 1),
        repeatUnit: RepeatUnit.month,
        repeatEvery: 2,
        repeatTimes: 5,
        occurrenceIndex: 1,
        seriesId: 'series-1',
        paidAt: DateTime(2026, 12, 1, 9, 30),
        createdAtMs: 100,
        updatedAtMs: 200,
      );
      final restored = Bill.fromMap(bill.toMap());
      expect(restored.id, bill.id);
      expect(restored.title, bill.title);
      expect(restored.amountSatang, bill.amountSatang);
      expect(restored.dueDate, bill.dueDate);
      expect(restored.isRecurring, isTrue);
      expect(restored.repeatUnit, RepeatUnit.month);
      expect(restored.repeatEvery, 2);
      expect(restored.repeatTimes, 5);
      expect(restored.occurrenceIndex, 1);
      expect(restored.seriesId, 'series-1');
      expect(restored.paidAt, bill.paidAt);
      expect(restored.isPaid, isTrue);
      expect(restored.createdAtMs, 100);
      expect(restored.updatedAtMs, 200);
    });

    test('CORE-15 save_ahead_unit null แปลว่าใช้ค่าตั้งต้น ไม่ใช่ months', () {
      final map = Bill(
        id: 'b-null-unit',
        title: 'บิลใช้ค่าตั้งต้น',
        amountSatang: 10000,
        dueDate: DateTime(2026, 11, 29),
        repeatUnit: RepeatUnit.none,
        repeatEvery: 1,
        repeatTimes: null,
        createdAtMs: 1,
        updatedAtMs: 1,
      ).toMap();
      expect(map['save_ahead_unit'], isNull);
      final restored = Bill.fromMap(map);
      expect(restored.saveAheadMonths, isNull);
      expect(restored.saveAheadUnit, isNull);

      final plan = Calculator.calculate(
        bills: [restored],
        poolSatang: 0,
        today: DateTime(2026, 11, 23),
        defaultSaveAheadMonths: 1,
        defaultSaveAheadUnit: SaveAheadUnit.days,
      );
      expect(plan.bills, isEmpty);
    });

    test('CORE-14 LedgerEntry', () {
      final entry = LedgerEntry(
        id: 'e-1',
        type: LedgerType.withdrawal,
        amountSatang: -12345,
        date: DateTime(2026, 11, 22),
        billId: 'bill-1',
        note: 'ใช้จากคลัง',
        createdAtMs: 1,
        updatedAtMs: 2,
      );
      final restored = LedgerEntry.fromMap(entry.toMap());
      expect(restored.id, entry.id);
      expect(restored.type, LedgerType.withdrawal);
      expect(restored.amountSatang, -12345);
      expect(restored.date, entry.date);
      expect(restored.billId, 'bill-1');
      expect(restored.note, 'ใช้จากคลัง');
    });

    test('CORE-15 LedgerType storage name', () {
      for (final type in LedgerType.values) {
        expect(LedgerTypeX.fromStorage(type.storageName), type);
      }
    });
  });
}
