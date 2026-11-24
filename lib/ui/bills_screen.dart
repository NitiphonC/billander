import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../core/money.dart';
import 'design_system.dart';
import 'icon_draw_screen.dart';
import '../models/bill.dart';
import '../state/app_state.dart';
import 'widgets/bill_icon.dart';
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
          padding: AppSpace.actionScreenPadding,
          children: [
            Text(
              'บิลทั้งหมด',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpace.md),
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
            const SizedBox(height: AppSpace.md),
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

  String _repeatLabel(Bill bill) {
    if (!bill.isRecurring) return '';
    final unit =
        bill.repeatUnit == RepeatUnit.week ? 'สัปดาห์' : 'เดือน';
    final every = bill.repeatEvery == 1 ? '' : ' ${bill.repeatEvery}';
    final count = bill.repeatTimes == null
        ? ' ไม่จำกัด'
        : ' ${bill.repeatTimes} รอบ';
    return ' · ทุก$every $unit$count'
        ' (รอบที่ ${bill.occurrenceIndex + 1})';
  }

  String _saveAheadLabel(Bill bill) {
    final value = bill.saveAheadMonths ?? state.defaultSaveAheadMonths;
    final unit = bill.saveAheadUnit ??
        (bill.saveAheadMonths != null
            ? SaveAheadUnit.months
            : state.defaultSaveAheadUnit);

    // ใช้จำนวนวันจาก plan ถ้าบิลอยู่ในช่วงเก็บ (นับรวมวันจ่าย)
    //ไม่อยู่ในช่วงก็คำนวณตรง ๆ จากวันนี้ถึงวันจ่าย
    int days = 0;
    for (final item in state.plan.bills) {
      if (item.bill.id == bill.id) {
        days = item.daysRemaining;
        break;
      }
    }
    final diff = bill.dueDate.difference(state.today).inDays;
    if (diff < 0) {
      return ' · เก็บล่วงหน้า $value ${unit.label} · เลยกำหนด ${-diff} วัน';
    }
    if (days == 0) days = diff + 1;
    return ' · เก็บล่วงหน้า $value ${unit.label} · เหลืออีก $days วัน';
  }

  Widget _billTile(BuildContext context, Bill bill) {
    final isOverdue = bill.dueDate.isBefore(state.today);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: BillIconBadge(bill: bill),
      title: Text(bill.title),
      subtitle: Text(
        '${formatDateThai(bill.dueDate)}'
        '${_repeatLabel(bill)}'
        '${_saveAheadLabel(bill)}'
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
                              'บิลนี้เป็นบิลซ้ำ คุณสามารถลบเฉพาะรอบนี้หรือทุกรอบในอนาคตได้')
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
      padding: AppSpace.sheetPadding,
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
  late final TextEditingController _everyController;
  late final TextEditingController _timesController;
  late final TextEditingController _aheadController;
  late final TextEditingController _iconTextController;
  late int _iconColor;
  String? _iconDrawing;
  late DateTime _dueDate;
  late RepeatUnit _repeatUnit;
  late bool _forever;
  late bool _useDefaultAhead;
  late SaveAheadUnit _saveAheadUnit;
  bool _applyToFuture = false;
  String? _saveError;
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
    _repeatUnit = bill?.repeatUnit ?? RepeatUnit.none;
    _everyController =
        TextEditingController(text: (bill?.repeatEvery ?? 1).toString());
    _timesController = TextEditingController(
      text: (bill?.repeatTimes ?? 1).toString(),
    );
    _forever = bill?.repeatTimes == null;
    _useDefaultAhead = bill?.saveAheadMonths == null;
    _iconTextController =
        TextEditingController(text: bill?.iconText ?? '');
    _iconColor = bill?.iconColor ?? 0xFF1F7A6C;
    _iconDrawing = bill?.iconDrawing;
    _saveAheadUnit = bill?.saveAheadUnit ?? widget.state.defaultSaveAheadUnit;
    _aheadController = TextEditingController(
      text: (bill?.saveAheadMonths ?? widget.state.defaultSaveAheadMonths)
          .toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _everyController.dispose();
    _timesController.dispose();
    _aheadController.dispose();
    _iconTextController.dispose();
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
    try {
      await _saveInner(amount);
    } catch (_) {
      if (mounted) setState(() => _saveError = 'บันทึกไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  Future<void> _saveInner(int amount) async {
    final every = int.tryParse(_everyController.text) ?? 1;
    final times = _forever ? null : int.tryParse(_timesController.text) ?? 1;
    final ahead = _useDefaultAhead
        ? null
        : (int.tryParse(_aheadController.text) ?? 1);
    final bill = widget.bill;
    if (bill == null) {
      await widget.state.addBill(
        title: _titleController.text,
        amountSatang: amount,
        dueDate: _dueDate,
        repeatUnit: _repeatUnit,
        repeatEvery: every < 1 ? 1 : every,
        repeatTimes: _repeatUnit == RepeatUnit.none ? null : times,
        saveAheadMonths: ahead,
        saveAheadUnit: _useDefaultAhead ? null : _saveAheadUnit,
        iconText: _iconTextController.text.trim().isEmpty
            ? null
            : _iconTextController.text.trim(),
        iconColor: _iconColor,
        iconDrawing: _iconDrawing,
      );
    } else {
      await widget.state.updateBill(
        billId: bill.id,
        title: _titleController.text,
        amountSatang: amount,
        dueDate: _dueDate,
        repeatUnit: _repeatUnit,
        repeatEvery: every < 1 ? 1 : every,
        repeatTimes: _repeatUnit == RepeatUnit.none ? null : times,
        saveAheadMonths: ahead,
        saveAheadUnit: _useDefaultAhead ? null : _saveAheadUnit,
        iconText: _iconTextController.text.trim().isEmpty
            ? null
            : _iconTextController.text.trim(),
        iconColor: _iconColor,
        iconDrawing: _iconDrawing,
        applyToFuture: _applyToFuture,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Bill _previewBill() => Bill(
        id: 'preview',
        title: _titleController.text,
        amountSatang: 0,
        dueDate: _dueDate,
        iconText: _iconTextController.text.trim().isEmpty
            ? null
            : _iconTextController.text.trim(),
        iconColor: _iconColor,
        iconDrawing: _iconDrawing,
        createdAtMs: 0,
        updatedAtMs: 0);

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
          const SizedBox(height: AppSpace.xs),
          const Text(
            'บอกจำนวนเงิน วันที่จ่าย และความถี่ '
            'แอปจะคำนวณเองว่าต้องเก็บวันละเท่าไหร่',
          ),
          const SizedBox(height: AppSpace.lg),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'ชื่อบิล',
              hintText: 'เช่น ค่าเช่า, ค่าไฟ, ผ่อนมือถือ',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'กรอกชื่อบิล' : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'จำนวนเงิน (บาท)',
              hintText: 'เช่น 250 หรือ 250.50',
              prefixText: '฿ ',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final amount = Money.tryParse(v ?? '');
              if (amount == null || amount <= 0) return 'กรอกจำนวนให้ถูกต้อง';
              return null;
            },
          ),
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined),
                  const SizedBox(width: AppSpace.md),
                  Text(
                    '${_repeatUnit == RepeatUnit.none
                        ? 'วันที่ต้องจ่าย'
                        : 'วันจ่ายรอบแรก'}: ${formatDateThai(_dueDate)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'แตะเพื่อเปลี่ยนวัน · วันจ่ายก็ถือเป็นวันเก็บด้วยเสมอ',
            style: AppType.caption(context),
          ),
          const SizedBox(height: AppSpace.md),
          DropdownButtonFormField<RepeatUnit>(
            initialValue: _repeatUnit,
            decoration: const InputDecoration(
              labelText: 'บิลนี้จ่ายซ้ำไหม',
              helperText: 'จ่ายครั้งเดียว → ไม่ซ้ำ · จ่ายทุกเดือน → ทุกเดือน',
              border: OutlineInputBorder(),
            ),
            items: RepeatUnit.values
                .map((u) =>
                    DropdownMenuItem(value: u, child: Text(u.label)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _repeatUnit = value);
            },
          ),
          if (_repeatUnit != RepeatUnit.none) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                const Text('ทุก'),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    controller: _everyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return '≥1';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(_repeatUnit == RepeatUnit.week ? 'สัปดาห์' : 'เดือน'),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('จ่ายไปเรื่อย ๆ (ไม่มีรอบสุดท้าย)'),
              subtitle: const Text(
                'เปิด = สร้างบิลต่อไปเรื่อย ๆ (แสดงล่วงหน้า 1 ปี)',
              ),
              value: _forever,
              onChanged: (v) => setState(() => _forever = v),
            ),
            if (!_forever)
              TextFormField(
                controller: _timesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวนรอบทั้งหมด',
                  helperText: 'เช่น 3 = จ่าย 3 รอบ (รอบนี้ + อีก 2 รอบ)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'ต้องอย่างน้อย 1 รอบ';
                  return null;
                },
              ),
            const SizedBox(height: AppSpace.xs),
            Text(
              _forever
                  ? 'ระบบจะสร้างบิลต่อไปเรื่อย ๆ (แสดงล่วงหน้า 1 ปี)'
                  : 'ตัวอย่าง: ใส่ 3 = จ่ายทั้งหมด 3 รอบ (รอบนี้ + อีก 2 รอบ)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Text(
            'ระยะเก็บล่วงหน้า = แอปจะเริ่มบอกให้เก็บล่วงหน้านานแค่ไหน '
            '(นับวันจ่ายเป็น 1 วันด้วย)',
            style: AppType.caption(context),
          ),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ใช้ค่าที่ตั้งไว้ให้ทุกบิล'),
            subtitle: Text(
              _useDefaultAhead
                  ? 'เปิด = ใช้ค่าตั้งต้น ${widget.state.defaultSaveAheadMonths} '
                      '${widget.state.defaultSaveAheadUnit.label}\n'
                      'ปิด = ตั้งใหม่เฉพาะบิลนี้'
                  : 'บิลนี้ใช้ค่าที่ตั้งแยก ไม่ตามค่าตั้งต้น '
                      '(${widget.state.defaultSaveAheadMonths} '
                      '${widget.state.defaultSaveAheadUnit.label})',
            ),
            value: _useDefaultAhead,
            onChanged: (v) => setState(() => _useDefaultAhead = v),
          ),
          if (!_useDefaultAhead) ...[
            DropdownButtonFormField<SaveAheadUnit>(
              initialValue: _saveAheadUnit,
              decoration: const InputDecoration(
                labelText: 'หน่วย (วัน / เดือน / ปี)',
                border: OutlineInputBorder(),
              ),
              items: SaveAheadUnit.values
                  .map((u) =>
                      DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _saveAheadUnit = v);
              },
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _aheadController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'เก็บกี่${_saveAheadUnit.label} (รวมวันจ่าย)',
                helperText: switch (_saveAheadUnit) {
                  SaveAheadUnit.days =>
                    'ใส่ 1 = เฉพาะวันจ่าย · ใส่ 7 = วันจ่าย + อีก 6 วันก่อน',
                  SaveAheadUnit.months =>
                    'ใส่ 1 = เฉพาะเดือนที่จ่าย · ใส่ 2 = รวมเดือนก่อนหน้า',
                  SaveAheadUnit.years =>
                    'ใส่ 1 = เฉพาะปีที่จ่าย · ใส่ 2 = รวมปีก่อนหน้า',
                },
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'ต้องอย่างน้อย 1';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _useDefaultAhead = true;
                  _aheadController.text =
                      widget.state.defaultSaveAheadMonths.toString();
                }),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('กลับไปใช้ค่าตั้งต้น'),
              ),
            ),
          ],
          if (widget.bill != null && widget.bill!.isRecurring)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ใช้กับรอบในอนาคตด้วย'),
              subtitle: const Text(
                'เปิด = แก้รอบนี้และรอบที่ยังไม่จ่าย · ปิด = แก้เฉพาะรอบนี้',
              ),
              value: _applyToFuture,
              onChanged: (v) => setState(() => _applyToFuture = v),
            ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              BillIconBadge(bill: _previewBill(), size: 56),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'ไอคอนบิล',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'ไม่บังคับ — ใส่ตัวอักษรหรือวาดรูปเพื่อจำบิลได้ง่ายขึ้น',
            style: AppType.caption(context),
          ),
          const SizedBox(height: AppSpace.sm),
          TextFormField(
            controller: _iconTextController,
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'ตัวอักษรในไอคอน (1–3 ตัว)',
              hintText: 'เช่น เช่า, ฟิ, น้ำ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: 10,
            children: [
              for (final color in [
                const Color(0xFF1F7A6C),
                const Color(0xFF1976D2),
                const Color(0xFFD32F2F),
                const Color(0xFFF57C00),
                const Color(0xFF7B1FA2),
                const Color(0xFF388E3C),
                const Color(0xFF424242),
                const Color(0xFF00838F),
              ])
                GestureDetector(
                  onTap: () => setState(() => _iconColor = color.value),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: color.value == _iconColor
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final data = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IconDrawScreen(),
                  ),
                );
                if (data != null) setState(() => _iconDrawing = data);
              },
              icon: const Icon(Icons.draw),
              label: Text(_iconDrawing == null ? 'วาดไอคอนเอง' : 'วาดใหม่'),
            ),
          ),
          if (_iconDrawing != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _iconDrawing = null),
                child: const Text('ลบภาพวาด'),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
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
