import 'package:flutter/material.dart';

import '../core/calculator.dart';
import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';
import '../state/app_state.dart';
import 'design_system.dart';
import 'widgets/bill_icon.dart';
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
        padding: AppSpace.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('วันนี้', style: AppType.caption(context)),
                      Text(
                        formatDateThai(state.today),
                        style: AppType.headline(context),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showHelp(context),
                  child: const Text('วิธีใช้'),
                ),
                const SizedBox(width: AppSpace.xs),
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
            const SizedBox(height: AppSpace.md),
            if (state.availableUpdate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => state.openUpdateDownload(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update),
                        const SizedBox(width: AppSpace.md),
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
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _recordDeposit(context),
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('เก็บวันนี้'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _recordWithdrawal(context),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('ใช้จากคลัง'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            SectionCard(
              title: 'บิลที่รอจ่าย (${plan.bills.length})',
              child: _billList(context, plan),
            ),
            const SizedBox(height: AppSpace.md),
            _DailyPlanCard(state: state),
            if (state.userError != null) ...[
              const SizedBox(height: AppSpace.md),
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

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('วิธีใช้แอป', style: AppType.title(dialogContext)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. เพิ่มบิล', style: AppType.label(dialogContext)),
              const SizedBox(height: AppSpace.sm),
              Text('แท็บ "บิล" → กด + → ใส่ชื่อบิล จำนวนเงิน และวันที่จ่าย',
                  style: AppType.body(dialogContext)),
              const SizedBox(height: AppSpace.lg),
              Text('2. เก็บเงินตามยอดที่แอปบอก',
                  style: AppType.label(dialogContext)),
              const SizedBox(height: AppSpace.sm),
              Text(
                'หน้าภาพรวมบอกว่าวันนี้ต้องใส่เงินเท่าไหร่ — กด "เก็บวันนี้" '
                'เพื่อบันทึก เงินจะอยู่ใน "คลัง" รอจ่ายตอนถึงกำหนด',
                style: AppType.body(dialogContext),
              ),
              const SizedBox(height: AppSpace.lg),
              Text('3. ดูวันที่ต้องเก็บ', style: AppType.label(dialogContext)),
              const SizedBox(height: AppSpace.sm),
              Text(
                'แท็บ "ปฏิทิน" โชว์ยอดที่ต้องเก็บแต่ละวัน '
                '(แตะวันเพื่อดูว่ามาจากบิลไหน)',
                style: AppType.body(dialogContext),
              ),
              const SizedBox(height: AppSpace.lg),
              Text('4. ตั้งค่าถ้าต้องการ', style: AppType.label(dialogContext)),
              const SizedBox(height: AppSpace.sm),
              Text(
                'แท็บ "ตั้งค่า" แก้เงินในคลังได้โดยตรง '
                'และเปลี่ยนระยะเก็บล่วงหน้าที่ใช้กับทุกบิล',
                style: AppType.body(dialogContext),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
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
      padding: AppSpace.heroPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ต้องเก็บวันนี้',
              style: AppType.label(context).copyWith(color: Colors.white70)),
          const SizedBox(height: AppSpace.xs),
          Text(
            Money.format(plan.dailyRequiredSatang),
            style: AppType.display(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            plan.note ?? '',
            style: AppType.body(context).copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'เริ่มเก็บล่วงหน้า ${state.defaultSaveAheadMonths} '
            '${state.defaultSaveAheadUnit.label} (รวมวันจ่าย)'
            '${plan.excludedCount > 0 ? ' · ${plan.excludedCount} บิลยังไม่เข้าช่วง' : ''}',
            style: AppType.statLabel(context).copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(context, 'ในคลัง', Money.formatCompact(plan.poolSatang)),
              _stat(context, 'ต้องจ่ายรวม',
                  Money.formatCompact(plan.totalOutstandingSatang)),
              _stat(
                context,
                'วันถึงบิลแรก',
                plan.isEmpty ? '-' : '${plan.daysToEarliestDue} วัน',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.statLabel(context)
                .copyWith(color: Colors.white70)),
        const SizedBox(height: AppSpace.xs),
        Text(value,
            style: AppType.label(context).copyWith(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _billList(BuildContext context, SavingsPlan plan) {
    if (plan.bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Column(
          children: [
            Text(
              'ยังไม่มีบิลที่ต้องจ่าย',
              style: AppType.title(context),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'เริ่มใช้งาน 3 ขั้นตอน:\n'
              '1. กดแท็บ "บิล" → กด + เพื่อเพิ่มบิล\n'
              '2. ใส่ชื่อบิล จำนวนเงิน วันที่จ่าย\n'
              '3. กลับมาหน้าภาพรวม จะเห็นยอดที่ต้องเก็บวันนี้',
              textAlign: TextAlign.center,
              style: AppType.muted(context),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in plan.bills)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: BillIconBadge(bill: item.bill),
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
          'ปรับเงินในคลังได้ในแท็บตั้งค่า',
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
      defaultSaveAheadUnit: widget.state.defaultSaveAheadUnit,
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
