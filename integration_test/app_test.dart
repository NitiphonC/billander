import 'package:billandar/app.dart';
import 'package:billandar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cleanData() async {
    final db = AppDatabase.instance;
    await db.init();
    final bills = await db.getBills();
    await db.deleteBills(bills.map((b) => b.id).toList());
    final entries = await db.getEntries();
    for (final entry in entries) {
      await db.deleteEntry(entry.id);
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const BillandarApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  Future<void> addBillToday(
    WidgetTester tester, {
    required String title,
    required String amount,
  }) async {
    await tester.tap(find.text('บิล'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มบิล'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), title);
    await tester.enterText(fields.at(1), amount);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> record(
    WidgetTester tester, {
    required String button,
    required String amount,
    required String confirm,
  }) async {
    await tester.tap(find.text('ภาพรวม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), amount);
    await tester.tap(find.text(confirm));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('INT-01 เปิดแอพครั้งแรกแสดงภาพรวมว่าง', (tester) async {
    await cleanData();
    await pumpApp(tester);

    expect(find.text('ต้องเก็บวันนี้'), findsOneWidget);
    expect(find.text('฿0.00'), findsAtLeastNWidgets(1));
    expect(find.text('ยังไม่มีบิลที่ต้องจ่าย'), findsAtLeastNWidgets(1));
  });

  testWidgets('INT-02..07 ครบวงจร เพิ่มบิล → เก็บ → ใช้ → จ่าย', (tester) async {
    await cleanData();
    await pumpApp(tester);

    // INT-02 เพิ่มบิลวันนี้
    await addBillToday(tester, title: 'ค่าเช่า', amount: '100');
    expect(find.text('ค่าเช่า'), findsAtLeastNWidgets(1));

    // INT-03 กลับภาพรวม ยอดรายวัน = 100 (วันจ่ายคือวันนี้ → n=1)
    await tester.tap(find.text('ภาพรวม'));
    await tester.pumpAndSettle();
    expect(find.text('฿100.00'), findsAtLeastNWidgets(1));

    // INT-04 เก็บเงิน 100 → ไม่ต้องเก็บเพิ่ม
    await record(
      tester,
      button: 'เก็บวันนี้',
      amount: '100',
      confirm: 'บันทึก',
    );
    expect(find.text('฿0.00'), findsAtLeastNWidgets(1));

    // INT-05 เอาเงินไปใช้ 40 → ต้องเก็บ 40
    await record(
      tester,
      button: 'ใช้จากคลัง',
      amount: '40',
      confirm: 'ใช้เงิน',
    );
    expect(find.text('฿40.00'), findsAtLeastNWidgets(1));

    // เติมกลับให้ครบก่อนจ่าย
    await record(
      tester,
      button: 'เก็บวันนี้',
      amount: '40',
      confirm: 'บันทึก',
    );

    // INT-06 กดจ่ายบิล
    await tester.tap(find.text('ภาพรวม'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('ค่าเช่า'), findsNothing);
    expect(find.text('฿0.00'), findsAtLeastNWidgets(1));

    // INT-07 ยกเลิก dialog แบบไม่กรอกต้องไม่พัง
    await tester.tap(find.text('เก็บวันนี้'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
