import 'package:flutter/material.dart';

import '../core/calculator.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';
import '../models/ledger_entry.dart';
import '../state/app_state.dart';
import 'bills_screen.dart' show BillEditorSheet;
import 'widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  Map<String, int> _dailyByDate = {};
  Map<String, List<ProjectionContribution>> _breakdownByDate = {};

  @override
  void initState() {
    super.initState();
    _month = firstDayOfMonth(widget.state.today);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final bills = widget.state.billsForMonth(_month);
    final billsByDate = <String, List<Bill>>{};
    for (final bill in bills) {
      (billsByDate[dateKey(bill.dueDate)] ??= <Bill>[]).add(bill);
    }

    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday % 7;
    final totalDays = daysInMonth(_month);
    final todayKey = dateKey(widget.state.today);

    // ยอดที่ต้องเก็บรายวันสำหรับวันในอนาคต (คำนวณจากคลังปัจจุบัน)
    final projection = Calculator.project(
      bills: widget.state.bills,
      poolSatang: widget.state.poolSatang,
      today: widget.state.today,
      // ครอบลิมิตแบบปี/อัปเดตไม่จำกัดได้ด้วย (เดิม 120 วัน → บิลไกลหาย)
      maxDays: 1830,
      defaultSaveAheadMonths: widget.state.defaultSaveAheadMonths,
      defaultSaveAheadUnit: widget.state.defaultSaveAheadUnit,
      // ปฏิทินใช้คลังจริงทุกวัน ไม่จำลองการเก็บ/จ่ายในอนาคต
      simulateFutureSavings: false,
    );
    final dailyByDate = {
      for (final item in projection) dateKey(item.date): item.requiredSatang,
    };
    _dailyByDate = dailyByDate;
    _breakdownByDate = {
      for (final item in projection)
        dateKey(item.date): item.contributions,
    };
    final entriesByDay = <String, List<LedgerEntry>>{};
    for (final entry in widget.state.entriesForMonth(_month)) {
      (entriesByDay[dateKey(entry.date)] ??= <LedgerEntry>[]).add(entry);
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${thaiMonths[_month.month - 1]} ${_month.year + 543}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(
                () => _month = firstDayOfMonth(widget.state.today)),
            child: const Text('กลับไปวันนี้'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ตัวเลขในแต่ละวัน = ยอดที่ต้องเก็บในวันนั้น · แตะเพื่อดูว่ามาจากบิลไหน',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final label in thaiWeekdaysShort)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.82,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: leadingBlanks + totalDays,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = index - leadingBlanks + 1;
                final date = DateTime(_month.year, _month.month, day);
                final key = dateKey(date);
                final dayBills = billsByDate[key] ?? const <Bill>[];
                final isToday = key == todayKey;
                final isOverdue = dayBills.any((b) =>
                    !b.isPaid && b.dueDate.isBefore(widget.state.today));
                final hasUnpaid = dayBills.any((b) => !b.isPaid);
                final isPast = date.isBefore(widget.state.today);
                final dailySatang = dailyByDate[key] ?? 0;
                final dayEntries = entriesByDay[key] ?? const <LedgerEntry>[];

                return _dayCell(
                  context: context,
                  day: day,
                  isToday: isToday,
                  isPast: isPast,
                  dailySatang: dailySatang,
                  hasBill: dayBills.isNotEmpty,
                  hasPaidBill: dayBills.any((b) => b.isPaid),
                  hasDeposit:
                      dayEntries.any((e) => e.type == LedgerType.deposit),
                  hasWithdrawal: dayEntries
                      .any((e) => e.type == LedgerType.withdrawal),
                  isOverdue: isOverdue,
                  hasUnpaid: hasUnpaid,
                  onTap: () => _showDayDetails(context, date, dayBills),
                );
              },
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (!isPast && dailySatang > 0)
              Text(
                Money.formatCompact(dailySatang),
                style: TextStyle(
                  fontSize: 9,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    formatDateThai(date),
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (!date.isBefore(widget.state.today) &&
                      (_dailyByDate[dateKey(date)] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'วันนี้ต้องเก็บ ${Money.format(_dailyByDate[dateKey(date)] ?? 0)}',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(sheetContext).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  if (!date.isBefore(widget.state.today) &&
                      contributions.isNotEmpty) ...[
                    Text(
                      'ยอดที่ต้องเก็บวันนี้มาจาก',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    for (final item in contributions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item.title)),
                            Text(Money.format(item.amountSatang)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
                      style: Theme.of(sheetContext).textTheme.titleMedium),
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
                      style: Theme.of(sheetContext).textTheme.titleMedium),
                  if (entries.isEmpty) const Text('ยังไม่มีบันทึก'),
                  for (final entry in entries) _entryTile(entry),
                  const SizedBox(height: 16),
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
