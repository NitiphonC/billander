import '../core/date_utils.dart';

enum RepeatUnit { none, week, month }

extension RepeatUnitX on RepeatUnit {
  String get storageName => name;

  String get label => switch (this) {
        RepeatUnit.none => 'ไม่ซ้ำ',
        RepeatUnit.week => 'ทุกสัปดาห์',
        RepeatUnit.month => 'ทุกเดือน',
      };

  static RepeatUnit fromStorage(String? value) =>
      RepeatUnit.values.firstWhere(
        (e) => e.name == value,
        orElse: () => RepeatUnit.none,
      );
}

class Bill {
  final String id;
  final String title;
  final int amountSatang;
  final DateTime dueDate;

  /// ความถี่: ไม่ซ้ำ / ทุกสัปดาห์ / ทุกเดือน
  final RepeatUnit repeatUnit;
  /// ซ้ำทุกกี่หน่วย (1 = ทุกสัปดาห์/เดือน, 2 = ทุก 2 สัปดาห์/เดือน)
  final int repeatEvery;
  /// จำนวนรอบทั้งหมด รวมรอบแรก; null = ไม่จำกัด
  final int? repeatTimes;
  /// ลำดับที่ของรอบนี้ในชุด (เริ่มที่ 0)
  final int occurrenceIndex;

  final String? seriesId;
  final DateTime? paidAt;
  final int createdAtMs;
  final int updatedAtMs;

  const Bill({
    required this.id,
    required this.title,
    required this.amountSatang,
    required this.dueDate,
    this.repeatUnit = RepeatUnit.none,
    this.repeatEvery = 1,
    this.repeatTimes,
    this.occurrenceIndex = 0,
    this.seriesId,
    this.paidAt,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isPaid => paidAt != null;
  bool get isRecurring => repeatUnit != RepeatUnit.none;

  /// ใช้กับโค้ด/ข้อมูลเก่า
  bool get recurring => isRecurring;

  Bill copyWith({
    String? id,
    String? title,
    int? amountSatang,
    DateTime? dueDate,
    RepeatUnit? repeatUnit,
    int? repeatEvery,
    int? repeatTimes,
    bool clearRepeatTimes = false,
    int? occurrenceIndex,
    String? seriesId,
    bool clearSeriesId = false,
    DateTime? paidAt,
    bool clearPaidAt = false,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amountSatang: amountSatang ?? this.amountSatang,
      dueDate: dueDate ?? this.dueDate,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      repeatTimes:
          clearRepeatTimes ? null : (repeatTimes ?? this.repeatTimes),
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,
      seriesId: clearSeriesId ? null : (seriesId ?? this.seriesId),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amountSatang,
        'due_date': dateKey(dueDate),
        'repeat_unit': repeatUnit.storageName,
        'repeat_every': repeatEvery,
        'repeat_times': repeatTimes,
        'occurrence_index': occurrenceIndex,
        // เก็บ field เก่าไว้เพื่อความเข้ากันได้
        'recurring': isRecurring ? 1 : 0,
        'series_id': seriesId,
        'paid_at': paidAt == null ? null : iso(paidAt!),
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };

  factory Bill.fromMap(Map<String, dynamic> map) {
    final legacyRecurring = (map['recurring'] as int? ?? 0) == 1;
    final unit = map.containsKey('repeat_unit')
        ? RepeatUnitX.fromStorage(map['repeat_unit'] as String?)
        : (legacyRecurring ? RepeatUnit.month : RepeatUnit.none);
    return Bill(
      id: map['id'] as String,
      title: map['title'] as String,
      amountSatang: (map['amount'] as num).toInt(),
      dueDate: tryParseDateKey(map['due_date'] as String?) ?? DateTime.now(),
      repeatUnit: unit,
      repeatEvery: (map['repeat_every'] as num?)?.toInt() ?? 1,
      repeatTimes: (map['repeat_times'] as num?)?.toInt(),
      occurrenceIndex: (map['occurrence_index'] as num?)?.toInt() ?? 0,
      seriesId: map['series_id'] as String?,
      paidAt:
          map['paid_at'] == null ? null : parseIso(map['paid_at'] as String),
      createdAtMs: (map['created_at'] as num?)?.toInt() ?? 0,
      updatedAtMs: (map['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}
