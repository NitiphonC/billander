import 'package:intl/intl.dart';

/// เก็บเงินเป็นจำนวนเต็ม "สตางค์" เพื่อเลี่ยงปัญหาทศนิยมลอย
/// 1 บาท = 100 สตางค์
class Money {
  static const int perBaht = 100;

  static final NumberFormat _formatter =
      NumberFormat.currency(locale: 'en_US', symbol: '฿', decimalDigits: 2);

  static int fromBaht(double value) => (value * perBaht).round();

  static int? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * perBaht).round();
  }

  static double toBaht(int satang) => satang / perBaht;

  static String format(int satang) => _formatter.format(toBaht(satang));

  static String formatCompact(int satang) {
    final abs = satang.abs();
    // ใช้เลขสตางค์ (int) เป็นหลัก เพื่อไม่ให้ double เพี้ยนที่ยอดใหญ่ ๆ
    if (abs >= 1000000 * perBaht) {
      final millions = abs / (1000000 * perBaht);
      return '฿${millions.toStringAsFixed(1)}ล้าน';
    }
    if (abs >= 10000 * perBaht) {
      final thousands = abs / (1000 * perBaht);
      return '฿${thousands.toStringAsFixed(1)}k';
    }
    return format(satang);
  }

  /// ปัดขึ้นเสมอ เพื่อให้เก็บแล้ว "พอจ่ายพอดี" ไม่ขาดเศษสตางค์
  static int ceilDiv(int numerator, int denominator) {
    if (denominator <= 0) return numerator;
    if (numerator <= 0) return 0;
    return (numerator + denominator - 1) ~/ denominator;
  }
}
