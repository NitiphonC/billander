import 'package:billandar/core/app_config.dart';
import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> pumpCalendar(WidgetTester tester) async {
    final s = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await s.load();
    await s.updateSetting(settingDefaultSaveAheadMonths, '1');
    await s.updateSetting(settingDefaultSaveAheadUnit, SaveAheadUnit.days.name);
    await s.addBill(
      title: 'ต้นเดือน',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 23),
      repeatUnit: RepeatUnit.none,
      repeatEvery: 1,
      repeatTimes: null,
    );
    await s.addBill(
      title: 'ปลายเดือน',
      amountSatang: 25000,
      dueDate: DateTime(2026, 11, 29),
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
    addTearDown(s.dispose);
    return s;
  }

  testWidgets('UI-CAL-01 ลิมิต 1 วัน → มียอดเฉพาะวัน 23 และ 29', (tester) async {
    await pumpCalendar(tester);
    await tester.drag(find.byType(GridView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('฿100.00'), findsOneWidget);
    expect(find.text('฿250.00'), findsOneWidget);
    // วันที่ 24–28 ต้องไม่มียอดเก็บเลย
    expect(find.textContaining('฿'), findsNWidgets(2));
  });

  testWidgets('UI-CAL-03 กดวันที่ 29 เห็นลิสต์บิลที่มารวม', (tester) async {
    await pumpCalendar(tester);
    await tester.drag(find.byType(GridView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('฿250.00'));
    await tester.pumpAndSettle();

    expect(find.text('ยอดที่ต้องเก็บวันนี้มาจาก'), findsOneWidget);
    expect(find.text('ปลายเดือน'), findsWidgets);
    expect(find.text('รวม ฿250.00'), findsOneWidget);
  });
}
