import 'package:flutter/material.dart';

import '../../core/money.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.child,
    this.action,
    this.padding = const EdgeInsets.all(16),
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
            if (child != null) const SizedBox(height: 12),
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

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
