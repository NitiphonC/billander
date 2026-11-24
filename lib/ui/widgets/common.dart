import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/bill.dart';
import '../design_system.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.child,
    this.action,
    this.padding = AppSpace.cardPadding,
  });

  final String title;
  final Widget? child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            if (child != null) const SizedBox(height: AppSpace.md),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

Future<int?> showAmountDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String confirmLabel = 'บันทึก',
  bool allowZero = false,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(
      title: title,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      allowZero: allowZero,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    this.initialValue,
    required this.confirmLabel,
    required this.allowZero,
  });

  final String title;
  final String? initialValue;
  final String confirmLabel;
  final bool allowZero;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    // ต้อง dispose ตอนนี้ (dialog ถูกถอดออกจาก tree แล้ว) ไม่ใช่หลัง Navigator.pop
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'จำนวนเงิน (บาท)',
            prefixText: '฿ ',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final amount = Money.tryParse(value ?? '');
            if (amount == null) return 'กรอกตัวเลขให้ถูกต้อง';
            if (amount < 0) return 'ห้ามติดลบ';
            if (!widget.allowZero && amount == 0) return 'ต้องมากกว่า 0';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, Money.tryParse(_controller.text));
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String label = 'ค่าที่ต้องการ',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      initialValue: initialValue,
      label: label,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    this.initialValue,
    required this.label,
  });

  final String title;
  final String? initialValue;
  final String label;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

/// เลือกหน่วย + จำนวนสำหรับลิมิตเก็บล่วงหน้า
Future<({int value, SaveAheadUnit unit})?> showSaveAheadDialog(
  BuildContext context, {
  required int initialValue,
  required SaveAheadUnit initialUnit,
}) {
  return showDialog<({int value, SaveAheadUnit unit})>(
    context: context,
    builder: (_) => _SaveAheadDialog(
      initialValue: initialValue,
      initialUnit: initialUnit,
    ),
  );
}

class _SaveAheadDialog extends StatefulWidget {
  const _SaveAheadDialog({
    required this.initialValue,
    required this.initialUnit,
  });

  final int initialValue;
  final SaveAheadUnit initialUnit;

  @override
  State<_SaveAheadDialog> createState() => _SaveAheadDialogState();
}

class _SaveAheadDialogState extends State<_SaveAheadDialog> {
  late final TextEditingController _controller;
  late SaveAheadUnit _unit;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
    _unit = widget.initialUnit;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ระยะเก็บล่วงหน้า'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'เริ่มบอกให้เก็บล่วงหน้านานแค่ไหนก่อนวันจ่าย '
              '(นับวันจ่ายเป็น 1 วันด้วย)',
              style: AppType.caption(context),
            ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<SaveAheadUnit>(
              initialValue: _unit,
              decoration: const InputDecoration(
                labelText: 'หน่วย (วัน / เดือน / ปี)',
                border: OutlineInputBorder(),
              ),
              items: SaveAheadUnit.values
                  .map((u) =>
                      DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _unit = v);
              },
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'เก็บกี่${_unit.label} (รวมวันจ่าย)',
                helperText: switch (_unit) {
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
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'ต้องอย่างน้อย 1';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              (value: int.parse(_controller.text.trim()), unit: _unit),
            );
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
