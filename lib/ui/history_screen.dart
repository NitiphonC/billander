import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/ledger_entry.dart';
import '../state/app_state.dart';
import 'design_system.dart';
import 'widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = firstDayOfMonth(widget.state.today);
  }

  @override
  Widget build(BuildContext context) {
    final monthEntries = widget.state.entriesForMonth(_month);
    final deposit = monthEntries
        .where((e) => e.type == LedgerType.deposit)
        .fold<int>(0, (sum, e) => sum + e.amountSatang);
    final withdrawn = -monthEntries
        .where((e) => e.type == LedgerType.withdrawal)
        .fold<int>(0, (sum, e) => sum + e.amountSatang);
    final paid = -monthEntries
        .where((e) => e.type == LedgerType.payment)
        .fold<int>(0, (sum, e) => sum + e.amountSatang);

    final grouped = <String, List<LedgerEntry>>{};
    for (final entry in monthEntries) {
      (grouped[dateKey(entry.date)] ??= <LedgerEntry>[]).add(entry);
    }

    final today = widget.state.today;
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;
    final elapsedDays = isCurrentMonth ? today.day : daysInMonth(_month);
    final recordedDays = grouped.length;
    final missedDays = elapsedDays - recordedDays;

    return SafeArea(
      child: ListView(
        padding: AppSpace.screenPadding,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () =>
                    setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
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
                onPressed: () =>
                    setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'สรุปเดือนนี้',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summary(context, 'เก็บได้', Money.formatCompact(deposit),
                    Colors.green),
                _summary(
                    context, 'ใช้ไป', Money.formatCompact(withdrawn), Colors.red),
                _summary(context, 'จ่ายบิล', Money.formatCompact(paid),
                    Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'วันที่ไม่ได้บันทึก $missedDays วัน (ระบบคำนวณยอดต่อวันเพิ่มขึ้นอัตโนมัติ)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          if (monthEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.xxxl),
              child: Text('ยังไม่มีประวัติ', textAlign: TextAlign.center),
            ),
          for (final group in grouped.entries)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${tryParseDateKey(group.key)?.day ?? ''} '
                      '${thaiMonths[(tryParseDateKey(group.key)?.month ?? 1) - 1]}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    for (final entry in group.value) _entryTile(entry),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: AppType.statLabel(context)),
        const SizedBox(height: AppSpace.xs),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _entryTile(LedgerEntry entry) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        child: Icon(
          switch (entry.type) {
            LedgerType.deposit => Icons.savings_outlined,
            LedgerType.withdrawal => Icons.remove_circle_outline,
            LedgerType.payment => Icons.receipt_long_outlined,
            LedgerType.initial => Icons.account_balance_wallet_outlined,
          },
          size: 16,
        ),
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
