import 'package:flutter/material.dart';

import '../design_system.dart';

/// ปุ่ม "i" เล็ก ๆ ไว้ข้างหัวข้อ — กดแล้วเปิดกล่องข้อความอ่านได้สบาย
/// ใช้กับคำอธิบายที่ยาวเกิน 2 บรรทัดเท่านั้น
/// (ข้อความสั้น 1 บรรทัดยังควรโชว์เลย ไม่ต้องซ่อนหลังปุ่ม)
class AppInfoButton extends StatelessWidget {
  const AppInfoButton({
    super.key,
    required this.title,
    required this.body,
    this.label = 'i',
  });

  final String title;
  final String body;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'อ่านเพิ่มเติม: $title',
      child: Semantics(
        button: true,
        label: 'อ่านเพิ่มเติม: $title',
        child: SizedBox(
          width: AppSpace.xl,
          height: AppSpace.xl,
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(title, style: AppType.title(dialogContext)),
                content: SingleChildScrollView(
                  child: Text(body, style: AppType.body(dialogContext)),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('เข้าใจแล้ว'),
                  ),
                ],
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(AppSpace.xl, AppSpace.xl),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
              backgroundColor: colorScheme.surfaceContainerHigh,
            ),
            child: Text(
              label,
              style: AppType.label(context)
                  .copyWith(color: colorScheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}
