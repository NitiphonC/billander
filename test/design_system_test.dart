import 'dart:io';

import 'package:billandar/data/storage.dart';
import 'package:billandar/state/app_state.dart';
import 'package:billandar/ui/bills_screen.dart';
import 'package:billandar/ui/calendar_screen.dart';
import 'package:billandar/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DS — มาตรฐานการออกแบบ', () {
    test('DS-01 มาตราส่วนระยะห่างเป็น multiples of 4 และเรียงลำดับ', () {
      final scale = [
        AppSpace.xs,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xxxl,
      ];
      for (final value in scale) {
        expect(value % 4, 0, reason: '$value ต้องหาร 4 ได้');
      }
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
      expect(AppSpace.screenPadding.left, AppSpace.lg);
      expect(AppSpace.cardPadding.top, AppSpace.lg);
    });

    test('DS-02 ไม่มี font size หรือระยะห่างแบบสุ่มใน lib/ui', () {
      final files = Directory('${Directory.current.path}/lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final rawFontSize = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
      final rawGap = RegExp(r'SizedBox\((?:height|width):\s*(\d+)');
      for (final file in files) {
        if (file.path.endsWith('design_system.dart')) continue;
        final text = file.readAsStringSync();
        for (final match in rawFontSize.allMatches(text)) {
          expect(
            double.parse(match.group(1)!),
            greaterThanOrEqualTo(11),
            reason: '${file.path} ใช้ฟอนต์เล็กเกินไป: ${match.group(0)}',
          );
        }
        for (final match in rawGap.allMatches(text)) {
          expect(
            int.parse(match.group(1)!) % 4,
            0,
            reason: '${file.path} ใช้ระยะห่างนอกมาตราส่วน: ${match.group(0)}',
          );
        }
      }
    });

    testWidgets('DS-03 ลำดับชั้นตัวอักษรและ line-height', (tester) async {
      late TextStyle display;
      late TextStyle title;
      late TextStyle body;
      late TextStyle muted;
      late TextStyle caption;
      late TextStyle calendarAmount;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              display = AppType.display(context);
              title = AppType.title(context);
              body = AppType.body(context);
              muted = AppType.muted(context);
              caption = AppType.caption(context);
              calendarAmount = AppType.calendarAmount(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(display.fontSize, greaterThan(title.fontSize!));
      expect(title.fontSize, greaterThan(body.fontSize!));
      expect(body.height, greaterThanOrEqualTo(1.4));
      expect(muted.height, greaterThanOrEqualTo(1.4));
      expect(muted.color, isNotNull);
      expect(caption.fontSize, greaterThanOrEqualTo(11));
      expect(calendarAmount.fontSize, greaterThanOrEqualTo(11));
    });

    testWidgets('DS-04 ปฏิทินเลื่อนแนวตั้ง ไม่มีปุ่มซ้ายขวา', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        storage: WebStorage(),
        todayOverride: DateTime(2026, 11, 23),
      );
      await state.load();
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (_, __) => CalendarScreen(state: state),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('กลับไปวันนี้'), findsOneWidget);
      expect(find.textContaining('เลื่อนขึ้น–ลง'), findsOneWidget);
      expect(find.text('พฤศจิกายน 2569'), findsOneWidget);

      // SliverList สร้างเฉพาะเดือนที่อยู่ในวิว — เลื่อนลงแล้วต้องเจอเดือนถัดไป
      await tester.scrollUntilVisible(
        find.text('ธันวาคม 2569'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('ธันวาคม 2569'), findsOneWidget);
    });

    testWidgets('DS-05 สไตล์จริงของชื่อแถวต้องเท่ากับ rowTitle ไม่ใช่ 16px',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        storage: WebStorage(),
        todayOverride: DateTime(2026, 11, 23),
      );
      await state.load();
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => BillEditorSheet.show(ctx, state),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      TextStyle painted(Finder f) =>
          tester.renderObject<RenderParagraph>(f).text.style!;
      final title = painted(find.text('ลิมิตสำหรับบิลนี้'));
      final caption = painted(
        find.text('นับวันจ่ายเป็น 1 วันด้วย'),
      );

      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
      expect(caption.fontSize, 12);
      expect(title.fontSize! - caption.fontSize!, lessThanOrEqualTo(2));
    });

    test('DS-06 SwitchListTile ทุกตัวต้องระบุ style แบบ AppType', () {
      final files = Directory('${Directory.current.path}/lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains('SwitchListTile(')) continue;
          final block = lines.skip(i).take(12).join('\n');
          expect(
            block.contains('style: AppType.'),
            isTrue,
            reason:
                '${file.path}:${i + 1} SwitchListTile ไม่มี style: AppType.* '
                '(จะตกไปใช้ bodyLarge 16px ของ Material)',
          );
        }
      }
    });
  });
}
