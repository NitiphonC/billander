import 'package:billandar/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({bool allowZero = false, String? initialValue}) {
    return MaterialApp(
      home: _Harness(allowZero: allowZero, initialValue: initialValue),
    );
  }

  testWidgets('UI-01 กดยกเลิกแบบไม่กรอกแล้วไม่เกิด assertion', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI-03 กดบันทึกแบบไม่กรอกจะโชว์ error', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('กรอกตัวเลขให้ถูกต้อง'), findsOneWidget);
  });

  testWidgets('UI-06 กรอก 123.45 แล้วบันทึกได้ 12345 สตางค์', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123.45');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('result: 12345'), findsOneWidget);
  });

  testWidgets('UI-04 กรอก 0 ถูกปฏิเสธเมื่อ allowZero=false', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('ต้องมากกว่า 0'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('UI-07 allowZero=true กรอก 0 ได้', (tester) async {
    await tester.pumpWidget(harness(allowZero: true));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('result: 0'), findsOneWidget);
  });

  testWidgets('UI-05 กรอกติดลบถูกปฏิเสธ', (tester) async {
    await tester.pumpWidget(harness(allowZero: true));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '-5');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('ห้ามติดลบ'), findsOneWidget);
  });

  testWidgets('UI-08 initialValue แสดงในช่องกรอก', (tester) async {
    await tester.pumpWidget(harness(initialValue: '50'));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    expect(find.text('50'), findsOneWidget);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({this.allowZero = false, this.initialValue});

  final bool allowZero;
  final String? initialValue;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('result: $_result'),
            FilledButton(
              onPressed: () async {
                final value = await showAmountDialog(
                  context,
                  title: 'เก็บเงินวันนี้',
                  initialValue: widget.initialValue,
                  allowZero: widget.allowZero,
                );
                if (mounted) setState(() => _result = value);
              },
              child: const Text('เปิด'),
            ),
          ],
        ),
      ),
    );
  }
}
