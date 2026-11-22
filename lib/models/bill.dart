import '../core/date_utils.dart';

class Bill {
  final String id;
  final String title;
  final int amountSatang;
  final DateTime dueDate;
  final bool recurring;
  final String? seriesId;
  final DateTime? paidAt;
  final int createdAtMs;
  final int updatedAtMs;

  const Bill({
    required this.id,
    required this.title,
    required this.amountSatang,
    required this.dueDate,
    this.recurring = false,
    this.seriesId,
    this.paidAt,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isPaid => paidAt != null;

  Bill copyWith({
    String? id,
    String? title,
    int? amountSatang,
    DateTime? dueDate,
    bool? recurring,
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
      recurring: recurring ?? this.recurring,
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
        'recurring': recurring ? 1 : 0,
        'series_id': seriesId,
        'paid_at': paidAt == null ? null : iso(paidAt!),
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };

  factory Bill.fromMap(Map<String, dynamic> map) => Bill(
        id: map['id'] as String,
        title: map['title'] as String,
        amountSatang: (map['amount'] as num).toInt(),
        dueDate: tryParseDateKey(map['due_date'] as String?) ?? DateTime.now(),
        recurring: (map['recurring'] as int? ?? 0) == 1,
        seriesId: map['series_id'] as String?,
        paidAt: map['paid_at'] == null ? null : parseIso(map['paid_at'] as String),
        createdAtMs: (map['created_at'] as num?)?.toInt() ?? 0,
        updatedAtMs: (map['updated_at'] as num?)?.toInt() ?? 0,
      );
}
