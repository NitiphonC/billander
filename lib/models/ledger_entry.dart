import '../core/date_utils.dart';

enum LedgerType { initial, deposit, withdrawal, payment }

extension LedgerTypeX on LedgerType {
  String get storageName => name;

  String get label => switch (this) {
        LedgerType.initial => 'เงินตั้งต้น',
        LedgerType.deposit => 'เก็บเงิน',
        LedgerType.withdrawal => 'ใช้จากคลัง',
        LedgerType.payment => 'จ่ายบิล',
      };

  static LedgerType fromStorage(String value) =>
      LedgerType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => LedgerType.deposit,
      );
}

class LedgerEntry {
  final String id;
  final LedgerType type;
  /// บวก = เงินเข้า, ลบ = เงินออก
  final int amountSatang;
  final DateTime date;
  final String? billId;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amountSatang,
    required this.date,
    this.billId,
    this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  LedgerEntry copyWith({
    String? id,
    LedgerType? type,
    int? amountSatang,
    DateTime? date,
    String? billId,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      amountSatang: amountSatang ?? this.amountSatang,
      date: date ?? this.date,
      billId: billId ?? this.billId,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.storageName,
        'amount': amountSatang,
        'date': dateKey(date),
        'bill_id': billId,
        'note': note,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        id: map['id'] as String,
        type: LedgerTypeX.fromStorage(map['type'] as String),
        amountSatang: (map['amount'] as num).toInt(),
        date: tryParseDateKey(map['date'] as String?) ?? DateTime.now(),
        billId: map['bill_id'] as String?,
        note: map['note'] as String?,
        createdAtMs: (map['created_at'] as num?)?.toInt() ?? 0,
        updatedAtMs: (map['updated_at'] as num?)?.toInt() ?? 0,
      );
}
