import 'package:billandar/data/storage.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:billandar/ui/dashboard_screen.dart';
import 'package:billandar/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> freshState(WidgetTester tester) async {
    final s = AppState(
      storage: WebStorage(),
      todayOverride: DateTime(2026, 11, 23),
    );
    await s.load();
    addTearDown(s.dispose);
    return s;
  }

  testWidgets('UI-HELP-01 ปุ่มวิธีใช้แอปเปิดคู่มือ 4 ขั้นตอน', (tester) async {
    final s = await freshState(tester);
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => DashboardScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('วิธีใช้'));
    await tester.pumpAndSettle();

    expect(find.text('วิธีใช้แอป'), findsOneWidget);
    expect(find.text('1. เพิ่มบิล'), findsOneWidget);
    expect(find.text('2. เก็บเงินตามยอดที่แอปบอก'), findsOneWidget);
    expect(find.text('3. ดูวันที่ต้องเก็บ'), findsOneWidget);
    expect(find.text('4. ตั้งค่าถ้าต้องการ'), findsOneWidget);

    await tester.tap(find.text('เข้าใจแล้ว'));
    await tester.pumpAndSettle();
    expect(find.text('วิธีใช้แอป'), findsNothing);
  });

  testWidgets('UI-EMPTY-01 หน้าเปล่าโชว์ 3 ขั้นตอนเริ่มใช้', (tester) async {
    final s = await freshState(tester);
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => DashboardScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบิลที่ต้องจ่าย'), findsWidgets);
    expect(find.textContaining('1. กดแท็บ "บิล"'), findsOneWidget);
    expect(find.textContaining('3. กลับมาหน้าภาพรวม'), findsOneWidget);
  });

  testWidgets('UI-FORM-01 ฟอร์มบิลมีตัวอย่างในแต่ละช่อง', (tester) async {
    final s = await freshState(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => BillEditorSheet.show(ctx, s),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ใส่ชื่อ จำนวนเงิน วันที่จ่าย — แอปคำนวณยอดต่อวันให้'),
        findsOneWidget);
    expect(find.text('เช่น ค่าเช่า, ค่าไฟ, ผ่อนมือถือ'), findsOneWidget);
    expect(find.text('เช่น 250 หรือ 250.50'), findsOneWidget);
    expect(find.textContaining('วันจ่ายก็ถือเป็นวันเก็บด้วยเสมอ'), findsOneWidget);
    expect(find.textContaining('จ่ายครั้งเดียว → ไม่ซ้ำ'), findsOneWidget);
    expect(find.text('ระยะเก็บล่วงหน้า'), findsOneWidget);
    expect(find.text('นับวันจ่ายเป็น 1 วันด้วย'), findsOneWidget);
    expect(find.text('ตั้งแยก'), findsOneWidget);
    expect(find.byTooltip('อ่านเพิ่มเติม: ระยะเก็บล่วงหน้าคืออะไร'),
        findsOneWidget);
  });

  testWidgets('UI-INFO-01 กดปุ่ม i เปิดกล่องคำอธิบายแล้วปิดได้',
      (tester) async {
    final s = await freshState(tester);
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: s,
        builder: (_, __) => SettingsScreen(state: s),
      ),
    ));
    await tester.pumpAndSettle();

    // ListView สร้างเฉพาะส่วนที่อยู่ในวิว → ใช้การ์ดแรกที่มองเห็น
    await tester.tap(find.byTooltip('อ่านเพิ่มเติม: คลังเงินคืออะไร'));
    await tester.pumpAndSettle();

    expect(find.text('คลังเงินคืออะไร'), findsOneWidget);
    expect(find.textContaining('ตรงกับคำว่า "ในคลัง"'), findsOneWidget);
    expect(find.text('เข้าใจแล้ว'), findsOneWidget);

    await tester.tap(find.text('เข้าใจแล้ว'));
    await tester.pumpAndSettle();
    expect(find.text('คลังเงินคืออะไร'), findsNothing);
  });
}
