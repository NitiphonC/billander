import 'package:flutter/material.dart';

import '../core/calculator.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';
import '../models/ledger_entry.dart';
import '../state/app_state.dart';
import 'bills_screen.dart' show BillEditorSheet;
import 'design_system.dart';
import 'widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// เรียงเดือนจากเดือนปัจจุบันไปข้างหน้า — ผู้ใช้เลื่อนขึ้น/ลงได้ต่อเนื่อง
  /// ครอบลิมิตแบบปี/ไม่จำกัดของบิล (เดิม 24 เดือน → บิลไกลไม่โชว์)
  static const _futureMonths = 60;

  late final ScrollController _scrollController;
  late final List<DateTime> _months;
  Map<String, int> _dailyByDate = {};
  Map<String, List<ProjectionContribution>> _breakdownByDate = {};

  @override
  void initState() {
    super.initState();
    final first = firstDayOfMonth(widget.state.today);
    _months = [
      for (var i = 0; i <= _futureMonths; i++)
        DateTime(first.year, first.month + i, 1),
    ];
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _backToToday() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ยอดที่ต้องเก็บรายวัน — ปฏิทินใช้คลังจริง ไม่จำลองการเก็บ/จ่ายในอนาคต
    final projection = Calculator.project(
      bills: widget.state.bills,
      poolSatang: widget.state.poolSatang,
      today: widget.state.today,
      maxDays: 3650,
      defaultSaveAheadMonths: widget.state.defaultSaveAheadMonths,
      defaultSaveAheadUnit: widget.state.defaultSaveAheadUnit,
      simulateFutureSavings: false,
    );
    final dailyByDate = {
      for (final item in projection) dateKey(item.date): item.requiredSatang,
    };
    _dailyByDate = dailyByDate;
    _breakdownByDate = {
      for (final item in projection) dateKey(item.date): item.contributions,
    };
    final todayKey = dateKey(widget.state.today);

    return SafeArea(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'เลื่อนขึ้น–ลงเพื่อเปลี่ยนเดือน · แตะวันเพื่อดูยอด',
                      style: AppType.caption(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _backToToday,
                    child: const Text('กลับไปวันนี้'),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: _months.length,
            itemBuilder: (context, index) =>
                _monthSection(context, _months[index], dailyByDate, todayKey),
          ),
        ],
      ),
    );
  }

  Widget _monthSection(
    BuildContext context,
    DateTime month,
    Map<String, int> dailyByDate,
    String todayKey,
  ) {
    final billsByDate = <String, List<Bill>>{};
    for (final bill in widget.state.billsForMonth(month)) {
      (billsByDate[dateKey(bill.dueDate)] ??= <Bill>[]).add(bill);
    }
    final entriesByDay = <String, List<LedgerEntry>>{};
    for (final entry in widget.state.entriesForMonth(month)) {
      (entriesByDay[dateKey(entry.date)] ??= <LedgerEntry>[]).add(entry);
    }
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday % 7;
    final totalDays = daysInMonth(month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${thaiMonths[month.month - 1]} ${month.year + 543}',
            textAlign: TextAlign.center,
            style: AppType.title(context),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (final label in thaiWeekdaysShort)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppType.caption(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 0.82,
            mainAxisSpacing: AppSpace.xs,
            crossAxisSpacing: AppSpace.xs,
            children: [
              for (var i = 0; i < leadingBlanks; i++)
                const SizedBox.shrink(),
              for (var day = 1; day <= totalDays; day++) _dayCellFor(
                context: context,
                month: month,
                day: day,
                dailyByDate: dailyByDate,
                billsByDate: billsByDate,
                entriesByDay: entriesByDay,
                todayKey: todayKey,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
  }

  Widget _dayCellFor({
    required BuildContext context,
    required DateTime month,
    required int day,
    required Map<String, int> dailyByDate,
    required Map<String, List<Bill>> billsByDate,
    required Map<String, List<LedgerEntry>> entriesByDay,
    required String todayKey,
  }) {
    final date = DateTime(month.year, month.month, day);
    final key = dateKey(date);
    final dayBills = billsByDate[key] ?? const <Bill>[];
    final dayEntries = entriesByDay[key] ?? const <LedgerEntry>[];
    return _dayCell(
      context: context,
      day: day,
      isToday: key == todayKey,
      isPast: date.isBefore(widget.state.today),
      dailySatang: dailyByDate[key] ?? 0,
      hasBill: dayBills.isNotEmpty,
      hasPaidBill: dayBills.any((b) => b.isPaid),
      hasDeposit: dayEntries.any((e) => e.type == LedgerType.deposit),
      hasWithdrawal: dayEntries.any((e) => e.type == LedgerType.withdrawal),
      isOverdue: dayBills.any((b) =>
          !b.isPaid && b.dueDate.isBefore(widget.state.today)),
      hasUnpaid: dayBills.any((b) => !b.isPaid),
      onTap: () => _showDayDetails(context, date, dayBills),
    );
  }

  Widget _dayCell({
    required BuildContext context,
    required int day,
    required bool isToday,
    required bool isPast,
    required int dailySatang,
    required bool hasBill,
    required bool hasPaidBill,
    required bool hasDeposit,
    required bool hasWithdrawal,
    required bool isOverdue,
    required bool hasUnpaid,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = isOverdue
        ? theme.colorScheme.error
        : hasUnpaid
            ? theme.colorScheme.primary
            : theme.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          color: isToday
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: AppType.label(context).copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (!isPast && dailySatang > 0)
              Text(
                Money.formatCompact(dailySatang),
                style: AppType.calendarAmount(context),
              ),
            if (isPast) ...[
              if (hasPaidBill)
                const Icon(Icons.check_circle, size: 11, color: Colors.green),
              if (hasBill && !hasPaidBill)
                Icon(Icons.receipt_long_outlined, size: 11, color: color),
              if (hasDeposit)
                const Icon(Icons.savings_outlined, size: 11, color: Colors.green),
              if (hasWithdrawal)
                const Icon(
                  Icons.remove_circle_outline,
                  size: 11,
                  color: Colors.red,
                ),
            ] else if (hasBill)
              Icon(Icons.circle, size: 6, color: color),
          ],
        ),
      ),
    );
  }

  void _showDayDetails(BuildContext context, DateTime date, List<Bill> bills) {
    final entries = widget.state.entriesForDate(date);
    final contributions =
        _breakdownByDate[dateKey(date)] ?? const <ProjectionContribution>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: AppSpace.sheetPadding,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    formatDateThai(date),
                    style: AppType.headline(sheetContext),
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (!date.isBefore(widget.state.today) &&
                      (_dailyByDate[dateKey(date)] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Text(
                        'วันนี้ต้องเก็บ ${Money.format(_dailyByDate[dateKey(date)] ?? 0)}',
                        style: AppType.title(sheetContext).copyWith(
                          color: Theme.of(sheetContext).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (!date.isBefore(widget.state.today) &&
                      contributions.isNotEmpty) ...[
                    Text(
                      'ยอดที่ต้องเก็บวันนี้มาจาก',
                      style: AppType.title(sheetContext),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    for (final item in contributions)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.xs,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right, size: 14),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(child: Text(item.title)),
                            Text(Money.format(item.amountSatang)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.sm,
                      ),
                      child: Text(
                        'รวม ${Money.format(_dailyByDate[dateKey(date)] ?? 0)}',
                        style: TextStyle(
                          color: Theme.of(sheetContext).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                  Text('บิลวันนี้',
                      style: AppType.title(sheetContext)),
                  if (bills.isEmpty) const Text('ไม่มีบิล'),
                  for (final bill in bills)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(bill.title),
                      subtitle: Text(
                        '${Money.format(bill.amountSatang)}'
                        '${bill.isPaid ? ' · จ่ายแล้ว' : ' · รอจ่าย'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'แก้ไขบิล',
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              BillEditorSheet.show(
                                context,
                                widget.state,
                                bill: bill,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          if (bill.isPaid)
                            const Icon(Icons.check_circle, color: Colors.green)
                          else
                            IconButton.filledTonal(
                              tooltip: 'กดเมื่อจ่ายแล้ว',
                              onPressed: () async {
                                final result =
                                    await widget.state.markPaid(bill.id);
                                if (!sheetContext.mounted) return;
                                if (result == PaymentResult.insufficient) {
                                  showMessage(sheetContext, 'เงินในคลังไม่พอ');
                                } else if (result == PaymentResult.success) {
                                  showMessage(sheetContext, 'จ่ายบิลแล้ว');
                                }
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.check),
                            ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text('บันทึกเงินวันนี้',
                      style: AppType.title(sheetContext)),
                  if (entries.isEmpty) const Text('ยังไม่มีบันทึก'),
                  for (final entry in entries) _entryTile(entry),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      BillEditorSheet.show(
                        context,
                        widget.state,
                        initialDate: date,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มบิลวันนี้'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _entryTile(LedgerEntry entry) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.type == LedgerType.deposit
            ? Icons.savings_outlined
            : entry.type == LedgerType.payment
                ? Icons.receipt_long_outlined
                : Icons.remove_circle_outline,
      ),
      title: Text(entry.type.label),
      subtitle: Text(entry.note ?? '-'),
      trailing: Text(
        Money.format(entry.amountSatang),
        style: TextStyle(
          color: entry.amountSatang >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
