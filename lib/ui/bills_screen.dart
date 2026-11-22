import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../core/money.dart';
import '../models/bill.dart';
import '../state/app_state.dart';
import 'widgets/common.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bills = state.bills;
    final active = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final paid = bills.where((b) => b.isPaid).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            Text(
              'บิลทั้งหมด',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'รอจ่าย (${active.length})',
              child: active.isEmpty
                  ? const Text('ยังไม่มีบิล กด + เพื่อเพิ่ม')
                  : Column(
                      children: [
                        for (final bill in active) _billTile(context, bill),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'จ่ายแล้ว (${paid.length})',
              child: paid.isEmpty
                  ? const Text('ยังไม่มีบิลที่จ่ายแล้ว')
                  : Column(
                      children: [
                        for (final bill in paid.take(20))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.check, size: 18),
                            ),
                            title: Text(
                              bill.title,
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough),
                            ),
                            subtitle: Text(formatDateThai(bill.dueDate)),
                            trailing: Text(Money.format(bill.amountSatang)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BillEditorSheet.show(context, state),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มบิล'),
      ),
    );
  }

  Widget _billTile(BuildContext context, Bill bill) {
    final isOverdue = bill.dueDate.isBefore(state.today);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(bill.recurring ? Icons.repeat : Icons.receipt_long, size: 20),
      ),
      title: Text(bill.title),
      subtitle: Text(
        '${formatDateThai(bill.dueDate)}'
        '${bill.recurring ? ' · ทุกเดือน' : ''}'
        '${isOverdue ? ' · เลยกำหนด' : ''}',
      ),
      trailing: SizedBox(
        width: 110,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                Money.formatCompact(bill.amountSatang),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  BillEditorSheet.show(context, state, bill: bill);
                } else if (value == 'delete') {
                  final confirmed = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ลบบิล?'),
                      content: bill.recurring
                          ? const Text(
                              'บิลนี้เป็นบิลทุกเดือน คุณสามารถลบเฉพาะรอบนี้หรือทุกรอบในอนาคตได้')
                          : const Text('ต้องการลบบิลนี้หรือไม่?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, 'cancel'),
                            child: const Text('ยกเลิก')),
                        if (bill.recurring)
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, 'all'),
                              child: const Text('ลบทุกรอบ')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, 'once'),
                            child: const Text('ลบรอบนี้')),
                      ],
                    ),
                  );
                  if (confirmed == null ||
                      confirmed == 'cancel' ||
                      !context.mounted) {
                    return;
                  }
                  await state.deleteBill(
                    bill.id,
                    includeFuture: confirmed == 'all',
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                PopupMenuItem(value: 'delete', child: Text('ลบ')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BillEditorSheet extends StatelessWidget {
  const BillEditorSheet._({required this.state, this.bill, this.initialDate});

  final AppState state;
  final Bill? bill;
  final DateTime? initialDate;

  static Future<void> show(
    BuildContext context,
    AppState state, {
    Bill? bill,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BillEditorSheet._(
          state: state,
          bill: bill,
          initialDate: initialDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: _BillEditorForm(
        state: state,
        bill: bill,
        initialDate: initialDate,
      ),
    );
  }
}

class _BillEditorForm extends StatefulWidget {
  const _BillEditorForm({
    required this.state,
    this.bill,
    this.initialDate,
  });

  final AppState state;
  final Bill? bill;
  final DateTime? initialDate;

  @override
  State<_BillEditorForm> createState() => _BillEditorFormState();
}

class _BillEditorFormState extends State<_BillEditorForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _dueDate;
  late bool _recurring;
  bool _applyToFuture = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    _titleController = TextEditingController(text: bill?.title ?? '');
    _amountController = TextEditingController(
      text: bill == null ? '' : Money.toBaht(bill.amountSatang).toStringAsFixed(0),
    );
    _dueDate = bill?.dueDate ?? widget.initialDate ?? widget.state.today;
    _recurring = bill?.recurring ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final bill = widget.bill;
    if (bill == null) {
      await widget.state.addBill(
        title: _titleController.text,
        amountSatang: amount,
        dueDate: _dueDate,
        recurring: _recurring,
      );
    } else {
      await widget.state.updateBill(
        billId: bill.id,
        title: _titleController.text,
        amountSatang: amount,
        dueDate: _dueDate,
        recurring: _recurring,
        applyToFuture: _applyToFuture,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.bill == null ? 'เพิ่มบิล' : 'แก้ไขบิล',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'ชื่อรายจ่าย',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'กรอกชื่อบิล' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'จำนวนเงิน (บาท)',
              prefixText: '฿ ',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final amount = Money.tryParse(v ?? '');
              if (amount == null || amount <= 0) return 'กรอกจำนวนให้ถูกต้อง';
              return null;
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined),
                  const SizedBox(width: 12),
                  Text('วันจ่าย: ${formatDateThai(_dueDate)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ซ้ำทุกเดือน'),
            subtitle: const Text('สร้างบิลอัตโนมัติล่วงหน้า 12 เดือน'),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          if (widget.bill != null && widget.bill!.recurring)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ใช้กับรอบในอนาคตด้วย'),
              value: _applyToFuture,
              onChanged: (v) => setState(() => _applyToFuture = v),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
