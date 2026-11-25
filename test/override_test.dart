import 'dart:convert';

import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:billandar/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> legacyBillMap({
    required String id,
    required int value,
    bool includeUnit = false,
  }) =>
      {
        'id': id,
        'title': 'บิลเก่า',
        'amount': 10000,
        'due_date': '2026-12-10',
        'repeat_unit': 'none',
        'repeat_every': 1,
        'repeat_times': null,
        'occurrence_index': 0,
        'save_ahead_months': value,
        if (includeUnit) 'save_ahead_unit': 'months',
        'created_at': 1,
        'updated_at': 1,
      };

  Future<AppState> stateWith(Map<String, dynamic> bills) async {
    SharedPreferences.setMockInitialValues({
      'billandar_bills': jsonEncode({
        for (final entry in bills.entries) entry.key: jsonEncode(entry.value),
      }),
      'billandar_settings': jsonEncode({
        'default_save_ahead_months': '1',
        'default_save_ahead_unit': 'days',
      }),
      'billandar_entries': '{}',
    });
    final state = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await state.load();
    addTearDown(state.dispose);
    return state;
  }

  Future<Map<String, dynamic>> rawBill(String id) =>
      SharedPreferences.getInstance().then((p) =>
          jsonDecode(jsonDecode(p.getString('billandar_bills')!)[id] as String)
              as Map<String, dynamic>);

  testWidgets('OVR-01 override แบบเก่า (มีค่า ไม่มีหน่วย) โชว์เป็นเดือน',
      (tester) async {
    final state = await stateWith({'b1': legacyBillMap(id: 'b1', value: 7)});

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () =>
                BillEditorSheet.show(ctx, state, bill: state.bills.single),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7 เดือน'), findsOneWidget);
    expect(find.textContaining('7 วัน'), findsNothing);
  });

  testWidgets('OVR-02 แก้ชื่อบิลเก่าแล้วบันทึก ไม่เขียนหน่วยผิด',
      (tester) async {
    final state = await stateWith({'b1': legacyBillMap(id: 'b1', value: 7)});

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () =>
                BillEditorSheet.show(ctx, state, bill: state.bills.single),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ชื่อใหม่');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    final raw = await rawBill('b1');
    expect(raw['save_ahead_months'], 7);
    expect(
      raw['save_ahead_unit'] == null || raw['save_ahead_unit'] == 'months',
      isTrue,
      reason: 'ห้ามเขียน days ทับ override แบบเดือน',
    );
    expect(state.plan.bills, isNotEmpty);
  });

  test('OVR-03 รอบใหม่ของบิลซ้ำใช้ลิมิตระดับชุด ไม่ใช่ของรอบที่แก้', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await state.load();
    addTearDown(state.dispose);

    await state.addBill(
      title: 'ผ่อน',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.week,
      repeatEvery: 1,
      repeatTimes: 2,
    );
    final anchor = state.bills.firstWhere((b) => b.occurrenceIndex == 0);
    await state.updateBill(
      billId: anchor.id,
      title: 'ผ่อน',
      amountSatang: 10000,
      dueDate: anchor.dueDate,
      repeatUnit: RepeatUnit.week,
      repeatEvery: 1,
      repeatTimes: 4,
      saveAheadMonths: 7,
      saveAheadUnit: SaveAheadUnit.days,
      applyToFuture: false,
    );

    final byIndex = {for (final b in state.bills) b.occurrenceIndex: b};
    expect(byIndex[0]!.saveAheadMonths, 7);
    expect(byIndex[1]!.saveAheadMonths, isNull);
    expect(byIndex[2]!.saveAheadMonths, isNull);
    expect(byIndex[3]!.saveAheadMonths, isNull);
  });

  test('OVR-04 updateBill ใส่ค่าแต่ไม่ใส่หน่วย → ผูกเป็นเดือน', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await state.load();
    addTearDown(state.dispose);

    await state.addBill(
      title: 'บิล',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
      saveAheadMonths: 3,
    );
    final raw = await rawBill(state.bills.single.id);
    expect(raw['save_ahead_unit'], 'months');
  });

  testWidgets('OVR-05 กล่องลิมิตปฏิเสธค่าเกินขีด', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final future = showSaveAheadDialog(
      tester.element(find.byType(SizedBox)),
      initialValue: 1,
      initialUnit: SaveAheadUnit.days,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '4000');
    await tester.tap(find.text('ใช้ค่านี้'));
    await tester.pumpAndSettle();

    expect(find.text('ใส่ได้ไม่เกิน 3650'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });
}
