import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// การแจ้งเตือนเป็นฟีเจอร์เสริม — หากอุปกรณ์ไม่อนุญาตต้องไม่ทำให้แอพพัง
  /// หรือโชว์ข้อความ error technical ให้ผู้ใช้เห็น
  Future<void> init() async {
    if (_ready) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// จัดการแจ้งเตือนรายวัน โดยข้อความจะถูกเขียนใหม่ทุกครั้งที่ยอดคำนวณเปลี่ยน
  Future<void> rescheduleDaily({
    required bool enabled,
    required TimeOfDay time,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(1001);
      if (!enabled) return;

      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'billandar_daily',
          'เตือนเก็บเงินรายวัน',
          channelDescription: 'แจ้งเตือนยอดที่ต้องเก็บในวันนี้',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      try {
        // exact alarm ต้องการสิทธิ์พิเศษบน Android 12+ — ถ้าไม่ได้ให้ใช้แบบ inexact
        await _plugin.zonedSchedule(
          1001,
          'Billandar · ต้องเก็บวันนี้',
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } on PlatformException {
        await _plugin.zonedSchedule(
          1001,
          'Billandar · ต้องเก็บวันนี้',
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {
      // เงียบไว้: แจ้งเตือนไม่ควรทำให้หน้าแอพขึ้นข้อความ error
    }
  }

  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'billandar_alerts',
          'แจ้งเตือนบิล',
          channelDescription: 'แจ้งเตือนบิลใกล้กำหนดหรือเลยกำหนด',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(2001, title, body, details);
    } catch (_) {
      // เงียบไว้เช่นกัน
    }
  }
}
