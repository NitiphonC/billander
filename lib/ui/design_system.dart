import 'package:flutter/material.dart';

/// มาตรฐานการออกแบบกลางของแอพ
/// ทุกระยะห่าง/ขนาดตัวอักษร/ความโค้ง ต้องมาจากที่นี่
/// ห้ามใส่เลขเองในหน้าจอ (ใช้ AppSpace / AppType / AppRadius แทน)
class AppSpace {
  const AppSpace._();

  /// มาตราส่วนระยะห่าง 4pt — ทุกค่าต้องหาร 4 ได้
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// เคลียร์พื้นที่ให้ปุ่มลอยด้านล่าง (FAB)
  static const double fabClearance = 88;

  static const EdgeInsets screenPadding =
      EdgeInsets.fromLTRB(lg, md, lg, xxl);
  static const EdgeInsets actionScreenPadding =
      EdgeInsets.fromLTRB(lg, md, lg, fabClearance);
  static const EdgeInsets sheetPadding =
      EdgeInsets.fromLTRB(lg, lg, lg, xxl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets heroPadding = EdgeInsets.all(xl);
  static const EdgeInsets listPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: sm);
}

/// ความโค้งของขอบ — ใช้กับการ์ด ปุ่ม และช่องกรอกให้ตรงกัน
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}

/// มาตราส่วนตัวอักษรจาก Theme.textTheme เท่านั้น
/// กำหนด line-height ให้ข้อความอ่านง่าย โดยเฉพาะภาษาไทย
///
/// สำคัญ: ห้ามปล่อย `Text` หรือ `SwitchListTile.title/subtitle` โดยไม่ใส่
/// `style:` — ค่าที่ Material ให้มา (bodyLarge 16px) ไม่ใช่ของ design system
/// และจะใหญ่กว่าคำอธิบาย AppType.caption (12px) ทันที
///
/// ลำดับบทบาท:
/// headline (24) > title (16, หัวข้อส่วน) > rowTitle (14, ชื่อแถวกดได้)
/// > body/muted (14, คำอธิบาย) > caption (12, ข้อความสั้นใต้ช่อง)
class AppType {
  const AppType._();

  static TextStyle _style(
    BuildContext context,
    TextStyle? Function(TextTheme) pick, {
    double height = 1.4,
    Color? color,
    FontWeight? weight,
  }) {
    final base = pick(Theme.of(context).textTheme) ?? const TextStyle();
    return base.copyWith(
      height: height,
      color: color,
      fontWeight: weight,
    );
  }

  /// หัวข้อหลักของหน้า
  static TextStyle display(BuildContext context) => _style(
        context,
        (t) => t.displaySmall,
        height: 1.2,
        weight: FontWeight.bold,
      );

  /// หัวข้อรอง / ยอดเงินใหญ่
  static TextStyle headline(BuildContext context) => _style(
        context,
        (t) => t.headlineSmall,
        height: 1.25,
        weight: FontWeight.bold,
      );

  /// หัวข้อส่วน (section)
  static TextStyle title(BuildContext context) => _style(
        context,
        (t) => t.titleMedium,
        weight: FontWeight.w700,
      );

  /// ชื่อรายการ / ป้ายกำกับหลัก
  static TextStyle label(BuildContext context) => _style(
        context,
        (t) => t.titleSmall,
        weight: FontWeight.w600,
      );

  /// ชื่อแถวที่กดได้ (SwitchListTile / ListTile / CheckboxListTile)
  /// ต้องใส่เสมอ — ค่าเริ่มต้นของ Material คือ bodyLarge 16px ซึ่งใหญ่เกินไป
  /// และเท่ากับหัวข้อ Sections ทำให้ดูเหมือนหัวข้อ
  static TextStyle rowTitle(BuildContext context) => label(context);

  /// คำอธิบายใต้ชื่อแถว — ใช้คู่กับ [rowTitle]
  static TextStyle rowSubtitle(BuildContext context) => caption(context);

  /// เนื้อหาปกติ
  static TextStyle body(BuildContext context) => _style(
        context,
        (t) => t.bodyMedium,
        height: 1.45,
      );

  /// คำอธิบายรอง — สีจางลงและบรรทัดหายใจได้
  static TextStyle muted(BuildContext context) => _style(
        context,
        (t) => t.bodyMedium,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// คำอธิบายสั้นใต้ช่องกรอก / ป้ายกำกับเล็ก
  static TextStyle caption(BuildContext context) => _style(
        context,
        (t) => t.labelMedium,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// ตัวเลขยอดรายวันในเซลล์ปฏิทิน (ห้ามเล็กกว่า labelSmall)
  static TextStyle calendarAmount(BuildContext context) => _style(
        context,
        (t) => t.labelSmall,
        height: 1.4,
        color: Theme.of(context).colorScheme.primary,
        weight: FontWeight.w700,
      );

  /// ป้ายตัวเลขในแถบสถิติของการ์ดยอด
  static TextStyle statLabel(BuildContext context) => _style(
        context,
        (t) => t.labelSmall,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}
