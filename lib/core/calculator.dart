import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';

/// ผลคำนวณของแต่ละบิล หลังนำเงินในคลังไปหักบิลใกล้กำหนดก่อน
class BillPlan {
  final Bill bill;
  final int coveredByPoolSatang;
  final int remainingSatang;
  /// จำนวนวันที่ยังเก็บได้ (นับรวมวันนี้และวันจ่าย) อย่างน้อย 1
  final int daysRemaining;
  final int perDaySatang;
  final bool isOverdue;
  final int daysOverdue;

  const BillPlan({
    required this.bill,
    required this.coveredByPoolSatang,
    required this.remainingSatang,
    required this.daysRemaining,
    required this.perDaySatang,
    required this.isOverdue,
    required this.daysOverdue,
  });
}

/// ภาพรวมแผนการเก็บเงิน ณ วันหนึ่ง
class SavingsPlan {
  final DateTime asOf;
  final int poolSatang;
  final int totalOutstandingSatang;
  final int coveredByPoolSatang;
  final int stillToSaveSatang;
  /// จำนวนเงินที่ต้องเก็บวันนี้ (ผลบวกของทุกบิล)
  final int dailyRequiredSatang;
  final List<BillPlan> bills;
  final DateTime? earliestDueDate;
  final int daysToEarliestDue;
  final int overdueCount;
  /// จำนวนบิลที่ยังอยู่นอกช่วง "เก็บล่วงหน้า" จึงยังไม่นำมาคำนวณวันนี้
  final int excludedCount;
  final String? note;

  const SavingsPlan({
    required this.asOf,
    required this.poolSatang,
    required this.totalOutstandingSatang,
    required this.coveredByPoolSatang,
    required this.stillToSaveSatang,
    required this.dailyRequiredSatang,
    required this.bills,
    required this.earliestDueDate,
    required this.daysToEarliestDue,
    required this.overdueCount,
    required this.excludedCount,
    required this.note,
  });

  bool get isEmpty => bills.isEmpty;
  bool get isFullyCovered => stillToSaveSatang <= 0;
  double get progress {
    if (totalOutstandingSatang <= 0) return 1;
    return (coveredByPoolSatang / totalOutstandingSatang).clamp(0.0, 1.0);
  }
}

/// ส่วนของยอดรายวันที่มาจากบิลใบหนึ่ง
class ProjectionContribution {
  final String billId;
  final String title;
  final int amountSatang;

  const ProjectionContribution({
    required this.billId,
    required this.title,
    required this.amountSatang,
  });
}

/// แนวโน้มการเก็บรายวัน ถ้าผู้ใช้เก็บตามยอดที่แนะนำทุกวัน
class ProjectionDay {
  final DateTime date;
  final int requiredSatang;
  final List<String> paidBillTitles;
  /// รายการบิลที่มารวมเป็น [requiredSatang]
  final List<ProjectionContribution> contributions;

  const ProjectionDay({
    required this.date,
    required this.requiredSatang,
    required this.paidBillTitles,
    required this.contributions,
  });
}

class Calculator {
  /// สร้างตารางวันต่อวันจนกว่าจะจ่ายบิลครบ
  /// สมมติว่าผู้ใช้เก็บวันละ [calculate] ทุกวัน และจ่ายบิลตอนถึงกำหนด
  static List<ProjectionDay> project({
    required List<Bill> bills,
    required int poolSatang,
    required DateTime today,
    int maxDays = 90,
    int defaultSaveAheadMonths = 1,
    SaveAheadUnit defaultSaveAheadUnit = SaveAheadUnit.months,
    bool applyPoolCoverage = true,
  }) {
    var balance = poolSatang;
    final pending = bills
        .where((b) => !b.isPaid)
        .map((b) => b.copyWith(paidAt: null, clearPaidAt: true))
        .toList();
    final result = <ProjectionDay>[];
    var cursor = dateOnly(today);
    final lastDue = pending.isEmpty
        ? cursor
        : pending.map((b) => b.dueDate).reduce((a, b) => a.isAfter(b) ? a : b);

    while (pending.isNotEmpty &&
        !cursor.isAfter(lastDue) &&
        result.length < maxDays) {
      final paidToday = pending
          .where((b) => dateKey(b.dueDate) == dateKey(cursor))
          .toList();
      final paidIds = <String>{};
      for (final bill in paidToday) {
        if (balance >= bill.amountSatang) {
          balance -= bill.amountSatang;
          paidIds.add(bill.id);
        }
      }
      final paidTitles = paidToday
          .where((b) => paidIds.contains(b.id))
          .map((b) => b.title)
          .toList();
      if (paidIds.isNotEmpty) {
        pending.removeWhere((b) => paidIds.contains(b.id));
      }

      final plan = calculate(
        bills: pending,
        poolSatang: balance,
        today: cursor,
        defaultSaveAheadMonths: defaultSaveAheadMonths,
        defaultSaveAheadUnit: defaultSaveAheadUnit,
        applyPoolCoverage: applyPoolCoverage,
      );
      result.add(ProjectionDay(
        date: cursor,
        requiredSatang: plan.dailyRequiredSatang,
        paidBillTitles: paidTitles,
        contributions: [
          for (final item in plan.bills)
            ProjectionContribution(
              billId: item.bill.id,
              title: item.bill.title,
              amountSatang: item.perDaySatang,
            ),
        ],
      ));
      balance += plan.dailyRequiredSatang;
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  /// สูตรหลัก:
  ///   1) เรียงบิลตามวันจ่าย (ใกล้สุดก่อน) แล้วนำคลังไปหักทีละบิล
  ///   2) ยอดที่เหลือของบิล = amount - ส่วนที่คลังรับรอง
  ///   3) n = วันจ่าย - วันนี้ + 1  (นับรวมสองวัน; ถ้าเลยกำหนดแล้ว n = 1)
  ///   4) ต้องเก็บ/วันของบิล = ceil(ส่วนที่เหลือ / n)
  ///   5) ยอดที่โชว์ = ผลบวกของทุกบิล
  /// คำนวณวันสิ้นสุดช่วงเก็บล่วงหน้าตามหน่วยที่เลือก
  static DateTime saveAheadHorizon(
    DateTime today,
    int value,
    SaveAheadUnit unit,
  ) {
    final n = value < 1 ? 1 : value;
    switch (unit) {
      case SaveAheadUnit.days:
        // วันจ่ายนับเป็น 1 วันในลิมิต → ตั้ง 7 วัน = วันจ่าย + อีก 6 วันก่อนหน้า
        // (ถ้า +n ตรง ๆ จะได้ 8 วัน ต้องตั้ง 6 แทน ซึ่งไม่ตรงความต้องการ)
        return dateOnly(today).add(Duration(days: n - 1));
      case SaveAheadUnit.months:
        return addMonthsClamped(today, n);
      case SaveAheadUnit.years:
        return addMonthsClamped(today, n * 12);
    }
  }

  static SavingsPlan calculate({
    required List<Bill> bills,
    required int poolSatang,
    required DateTime today,
    int defaultSaveAheadMonths = 1,
    SaveAheadUnit defaultSaveAheadUnit = SaveAheadUnit.months,
    bool applyPoolCoverage = true,
  }) {
    final t = dateOnly(today);

    // กรองบิลที่ยังอยู่นอกช่วงเก็บล่วงหน้า (default หรือกำหนดแยกต่อบิล)
    final unpaid = bills.where((b) => !b.isPaid).toList();
    final active = unpaid.where((bill) {
      final value = bill.saveAheadMonths ?? defaultSaveAheadMonths;
      final unit = bill.saveAheadUnit ??
          (bill.saveAheadMonths != null
              ? SaveAheadUnit.months
              : defaultSaveAheadUnit);
      return !bill.dueDate.isAfter(saveAheadHorizon(t, value, unit));
    }).toList()
      ..sort((a, b) {
        final byDue = a.dueDate.compareTo(b.dueDate);
        if (byDue != 0) return byDue;
        final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });

    // ปฏิทินต้องการ "ยอดที่แต่ละบิลขอเก็บในวันนั้น" แบบไม่หักคลัง
    // (หน้าภาพรวมใช้ค่าตั้งต้น = true ตามกฎเดิม)
    var available = applyPoolCoverage && poolSatang > 0 ? poolSatang : 0;
    var totalOutstanding = 0;
    var coveredTotal = 0;
    final plans = <BillPlan>[];

    for (final bill in active) {
      totalOutstanding += bill.amountSatang;

      // หักบิลใกล้กำหนดก่อน (FIFO ตามวันจ่าย)
      final cover = available < bill.amountSatang ? available : bill.amountSatang;
      available -= cover;
      coveredTotal += cover;

      final remaining = bill.amountSatang - cover;
      final diff = daysBetween(t, bill.dueDate);
      final isOverdue = diff < 0;
      final days = isOverdue ? 1 : diff + 1;
      final perDay = Money.ceilDiv(remaining, days);

      plans.add(BillPlan(
        bill: bill,
        coveredByPoolSatang: cover,
        remainingSatang: remaining,
        daysRemaining: days,
        perDaySatang: perDay,
        isOverdue: isOverdue,
        daysOverdue: isOverdue ? -diff : 0,
      ));
    }

    final dailyRequired = plans.fold<int>(0, (sum, p) => sum + p.perDaySatang);
    final stillToSave = totalOutstanding - coveredTotal;
    final overdueCount = plans.where((p) => p.isOverdue).length;
    final earliest = active.isEmpty ? null : active.first.dueDate;
    final toEarliest = earliest == null ? 0 : daysBetween(t, earliest) + 1;

    final excludedCount = unpaid.length - active.length;
    String? note;
    if (active.isEmpty && excludedCount > 0) {
      note = 'ยังไม่มีบิลเข้าช่วงเก็บ ($excludedCount บิลรออยู่)';
    } else if (active.isEmpty) {
      note = 'ยังไม่มีบิลที่ต้องจ่าย';
    } else if (overdueCount > 0) {
      note = 'มี $overdueCount บิลเลยกำหนด ต้องรีบจ่ายวันนี้';
    } else if (stillToSave <= 0) {
      note = 'เงินในคลังพอจ่ายทุกบิลแล้ว';
    } else if (dailyRequired == 0) {
      note = 'วันนี้ไม่ต้องเก็บเพิ่มแล้ว';
    } else {
      note = 'ถ้าเก็บตามนี้ทุกวัน จะพอดีตอนถึงวันจ่าย';
    }

    return SavingsPlan(
      asOf: t,
      poolSatang: poolSatang,
      totalOutstandingSatang: totalOutstanding,
      coveredByPoolSatang: coveredTotal,
      stillToSaveSatang: stillToSave < 0 ? 0 : stillToSave,
      dailyRequiredSatang: dailyRequired,
      bills: plans,
      earliestDueDate: earliest,
      daysToEarliestDue: toEarliest < 0 ? 0 : toEarliest,
      overdueCount: overdueCount,
      excludedCount: excludedCount,
      note: note,
    );
  }

  /// กดยืนยันจ่ายได้ก็ต่อเมื่อเงินในคลังพอจ่ายบิลนั้น
  static bool canPay({required int poolSatang, required int billAmountSatang}) =>
      poolSatang >= billAmountSatang;
}
