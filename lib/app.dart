import 'package:flutter/material.dart';

import 'services/sync_service.dart';
import 'ui/home_shell.dart';

class BillandarApp extends StatelessWidget {
  const BillandarApp({super.key, this.sync});

  /// ส่ง FirebaseSyncService เข้ามาได้เมื่อพร้อมซิงก์คลาวด์
  final SyncService? sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billandar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A6C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Prompt',
        textTheme: Typography.material2021().black.apply(
              fontFamily: 'Prompt',
              fontFamilyFallback: const ['NotoSansThai', 'sans-serif'],
            ),
      ),
      home: HomeShell(sync: sync),
    );
  }
}
