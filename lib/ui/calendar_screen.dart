import 'package:flutter/material.dart';

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

    final entriesByDate = <String, int>{};
    for (final entry in widget.state.entriesForMonth(_month)) {
      final key = dateKey(entry.date);
      entriesByDate[key] = (entriesByDate[key] ?? 0) + 1;
    }

    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday % 7;
    final totalDays = daysInMonth(_month);
    final todayKey = dateKey(widget.state.today);

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
                final hasEntry = entriesByDate.containsKey(key);
                final isOverdue = dayBills.any((b) =>
                    !b.isPaid && b.dueDate.isBefore(widget.state.today));
                final hasUnpaid = dayBills.any((b) => !b.isPaid);

                return _dayCell(
                  context: context,
                  day: day,
                  date: date,
                  dayBills: dayBills,
                  isToday: isToday,
                  hasEntry: hasEntry,
                  isOverdue: isOverdue,
                  hasUnpaid: hasUnpaid,
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
    required DateTime date,
    required List<Bill> dayBills,
    required bool isToday,
    required bool hasEntry,
    required bool isOverdue,
    required bool hasUnpaid,
  }) {
    final theme = Theme.of(context);
    final color = isOverdue
        ? theme.colorScheme.error
        : hasUnpaid
            ? theme.colorScheme.primary
            : theme.colorScheme.outline;

    return InkWell(
      onTap: () => _showDayDetails(context, date, dayBills),
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
            if (dayBills.isNotEmpty)
              Icon(Icons.circle, size: 7, color: color),
            if (hasEntry) Icon(Icons.savings_outlined, size: 11, color: color),
          ],
        ),
      ),
    );
  }

  void _showDayDetails(BuildContext context, DateTime date, List<Bill> bills) {
    final entries = widget.state.entriesForDate(date);
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
                      trailing: bill.isPaid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton.filledTonal(
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
