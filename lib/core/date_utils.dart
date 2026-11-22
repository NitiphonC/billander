import 'dart:convert';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? tryParseDateKey(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime parseIso(String value) => DateTime.parse(value);

String iso(DateTime d) => d.toIso8601String();

/// นับวันแบบรวมทั้งวันเริ่มต้นและวันสิ้นสุด
/// 1 -> 10 = 10 วัน (ตามตัวอย่างที่ผู้ใช้ยืนยัน)
int daysInclusive(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays + 1;

int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

int daysInMonth(DateTime d) =>
    DateTime(d.year, d.month + 1, 0).day;

DateTime addMonthsClamped(DateTime d, int months) {
  final target = DateTime(d.year, d.month + months, 1);
  final day = d.day > daysInMonth(target) ? daysInMonth(target) : d.day;
  return DateTime(target.year, target.month, day);
}

int monthIndex(DateTime d) => d.year * 12 + d.month - 1;

/// สร้างวันจ่ายของบิลซ้ำทุก [intervalMonths] เดือน ตั้งแต่ [anchor] ถึง [through]
/// คำนวณจาก anchor ทุกครั้งเพื่อไม่ให้วันที่เคลื่อน (เช่น 31 ม.ค. → 31 มี.ค. → 31 พ.ค.)
List<DateTime> recurringDueDates({
  required DateTime anchor,
  required int intervalMonths,
  required DateTime through,
  int maxCount = 60,
}) {
  final step = intervalMonths < 1 ? 1 : intervalMonths;
  final start = dateOnly(anchor);
  final end = dateOnly(through);
  final dates = <DateTime>[];
  for (var i = 0; i < maxCount; i++) {
    final date = addMonthsClamped(start, i * step);
    if (date.isAfter(end)) break;
    dates.add(date);
  }
  return dates;
}

DateTime firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

String encodeStringList(List<String> values) => jsonEncode(values);

List<String> decodeStringList(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) return const [];
  return decoded.map((e) => e.toString()).toList();
}

const thaiMonths = <String>[
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const thaiWeekdaysShort = <String>['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

String formatDateThai(DateTime d) =>
    '${d.day} ${thaiMonths[d.month - 1]} ${d.year + 543}';
