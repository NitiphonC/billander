import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('STATIC — ความเป็นส่วนตัวและข้อกำหนดการแจกจ่าย', () {
    final root = Directory.current.path;
    final pubspec = File('$root/pubspec.yaml').readAsStringSync();

    test('STATIC-01 ไม่มีแพ็กเกจวิเคราะห์/โฆษณา/ติดตาม', () {
      final forbidden = [
        'firebase',
        'analytics',
        'admob',
        'google_mobile_ads',
        'crashlytics',
        'facebook',
        'appsflyer',
        'amplitude',
      ];
      for (final name in forbidden) {
        expect(
          pubspec.toLowerCase().contains(name),
          isFalse,
          reason: 'pubspec.yaml ต้องไม่มี $name',
        );
      }
    });

    test('STATIC-02 ไม่มี emoji ในซอร์สที่ผู้ใช้เห็น', () {
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
        unicode: true,
      );
      final files = Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final text = file.readAsStringSync();
        final match = emoji.firstMatch(text);
        expect(
          match,
          isNull,
          reason: '${file.path} มี emoji: ${match?.group(0)}',
        );
      }
    });

    test('STATIC-03 Prompt font ถูก bundle และอ้างอิง', () {
      expect(pubspec, contains('family: Prompt'));
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        expect(pubspec, contains('Prompt-$weight.ttf'));
      }
      expect(File('$root/assets/fonts/OFL.txt').existsSync(), isTrue);
      final app = File('$root/lib/app.dart').readAsStringSync();
      expect(app, contains("fontFamily: 'Prompt'"));
    });

    test('STATIC-04 base href ตรงกับชื่อ repo ที่ deploy จริง', () {
      final index = File('$root/docs/index.html').readAsStringSync();
      expect(index, contains('<base href="/billander/">'));
    });

    test('STATIC-05 มี workflow สำหรับ build + deploy PWA', () {
      expect(
        File('$root/.github/workflows/deploy.yml').existsSync(),
        isTrue,
      );
    });
  });
}
