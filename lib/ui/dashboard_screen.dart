import 'package:flutter/material.dart';

import '../core/calculator.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';
import '../state/app_state.dart';
import 'widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final plan = state.plan;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('วันนี้', style: theme.textTheme.bodyMedium),
                      Text(
                        formatDateThai(state.today),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'ตรวจสอบอัปเดต',
                  onPressed: () async {
                    await state.checkForUpdate(force: true);
                    if (context.mounted) {
                      showMessage(
                        context,
                        state.availableUpdate == null
                            ? 'เป็นเวอร์ชันล่าสุดแล้ว'
                            : 'พบเวอร์ชันใหม่ ${state.availableUpdate!.versionName}',
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.availableUpdate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => state.openUpdateDownload(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'มีเวอร์ชันใหม่ ${state.availableUpdate!.versionName} '
                            '— แตะเพื่อดาวน์โหลด',
                          ),
                        ),
                        const Icon(Icons.download_outlined),
                      ],
                    ),
                  ),
                ),
              ),
            _heroCard(context, plan),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _recordDeposit(context),
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('เก็บวันนี้'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _recordWithdrawal(context),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('ใช้จากคลัง'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'บิลที่รอจ่าย (${plan.bills.length})',
              child: _billList(context, plan),
            ),
            const SizedBox(height: 12),
            _DailyPlanCard(state: state),
            if (state.userError != null) ...[
              const SizedBox(height: 12),
              Text(
                state.userError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, SavingsPlan plan) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ต้องเก็บวันนี้', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            Money.format(plan.dailyRequiredSatang),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.note ?? '',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'ลิมิตเก็บล่วงหน้า ${state.defaultSaveAheadMonths} เดือน'
            '${plan.excludedCount > 0 ? ' · มี ${plan.excludedCount} บิลรอนอกช่วง' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('ในคลัง', Money.formatCompact(plan.poolSatang)),
              _stat('ต้องจ่ายรวม', Money.formatCompact(plan.totalOutstandingSatang)),
              _stat(
                'วันถึงบิลแรก',
                plan.isEmpty ? '-' : '${plan.daysToEarliestDue} วัน',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _billList(BuildContext context, SavingsPlan plan) {
    if (plan.bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'ยังไม่มีบิลที่ต้องจ่าย\nกดแท็บ "บิล" เพื่อเพิ่มรายจ่าย',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final item in plan.bills)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Icon(
                item.bill.recurring ? Icons.repeat : Icons.receipt_long,
                size: 20,
              ),
            ),
            title: Text(item.bill.title),
            subtitle: Text(
              'จ่าย ${formatDateThai(item.bill.dueDate)} · '
              'วันละ ${Money.format(item.perDaySatang)}'
              '${item.coveredByPoolSatang > 0 ? ' · คลังรับรอง ${Money.formatCompact(item.coveredByPoolSatang)}' : ''}',
            ),
            trailing: item.isOverdue
                ? Chip(
                    label: Text('เลย ${item.daysOverdue} วัน'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  )
                : IconButton.filledTonal(
                    tooltip: 'กดเมื่อจ่ายแล้ว',
                    onPressed: () => _pay(context, item.bill),
                    icon: const Icon(Icons.check),
                  ),
          ),
      ],
    );
  }

  Future<void> _recordDeposit(BuildContext context) async {
    final amount = await showAmountDialog(context, title: 'เก็บเงินวันนี้');
    if (amount == null || !context.mounted) return;
    await state.recordDeposit(amount, note: 'เก็บรายวัน');
    if (context.mounted) {
      showMessage(
        context,
        'บันทึกแล้ว ตอนนี้ต้องเก็บวันละ '
        '${Money.format(state.plan.dailyRequiredSatang)}',
      );
    }
  }

  Future<void> _recordWithdrawal(BuildContext context) async {
    final amount = await showAmountDialog(
      context,
      title: 'เอาเงินจากคลังไปใช้',
      confirmLabel: 'ใช้เงิน',
    );
    if (amount == null || !context.mounted) return;
    await state.recordWithdrawal(amount, note: 'ใช้จากคลัง');
    if (context.mounted) {
      showMessage(
        context,
        'บันทึกแล้ว ตอนนี้ต้องเก็บวันละ '
        '${Money.format(state.plan.dailyRequiredSatang)}',
      );
    }
  }

  Future<void> _pay(BuildContext context, Bill bill) async {
    final result = await state.markPaid(bill.id);
    if (!context.mounted) return;
    switch (result) {
      case PaymentResult.success:
        showMessage(
          context,
          'จ่าย "${bill.title}" แล้ว · วันนี้ต้องเก็บ '
          '${Money.format(state.plan.dailyRequiredSatang)}',
        );
      case PaymentResult.insufficient:
        showMessage(
          context,
          'เงินในคลังไม่พอ (มี ${Money.format(state.poolSatang)} / '
          'ต้อง ${Money.format(bill.amountSatang)}) '
          'ปรับเงินตั้งต้นได้ในแท็บตั้งค่า',
        );
      case PaymentResult.notFound:
        break;
    }
  }
}

class _DailyPlanCard extends StatefulWidget {
  const _DailyPlanCard({required this.state});

  final AppState state;

  @override
  State<_DailyPlanCard> createState() => _DailyPlanCardState();
}

class _DailyPlanCardState extends State<_DailyPlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final days = Calculator.project(
      bills: widget.state.bills,
      poolSatang: widget.state.poolSatang,
      today: widget.state.today,
      maxDays: 60,
      defaultSaveAheadMonths: widget.state.defaultSaveAheadMonths,
    );
    final visible = _expanded ? days : days.take(7).toList();

    return SectionCard(
      title: 'ตารางเก็บรายวันที่แนะนำ',
      action: days.length > 7
          ? TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'ย่อ' : 'ดูทั้งหมด'),
            )
          : null,
      child: Column(
        children: [
          for (final day in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: SizedBox(
                width: 52,
                child: Text(
                  '${day.date.day}/${day.date.month}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              title: Text(
                day.requiredSatang == 0
                    ? 'ไม่ต้องเก็บ'
                    : 'เก็บ ${Money.format(day.requiredSatang)}',
              ),
              subtitle: day.paidBillTitles.isEmpty
                  ? null
                  : Text('จ่ายบิล: ${day.paidBillTitles.join(', ')}'),
              trailing: day.paidBillTitles.isEmpty
                  ? null
                  : const Icon(Icons.check_circle, color: Colors.green),
            ),
          if (days.isEmpty) const Text('ยังไม่มีบิลที่ต้องเก็บ'),
        ],
      ),
    );
  }
}
