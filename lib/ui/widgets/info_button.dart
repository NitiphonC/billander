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
        // วงกลมโชว์แค่ xl (20px) แต่พื้นที่กดขยายเป็น 44px ให้แตะง่าย
        child: InkWell(
          onTap: () => showDialog<void>(
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
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Container(
              width: AppSpace.xl,
              height: AppSpace.xl,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppType.label(context)
                    .copyWith(color: colorScheme.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
