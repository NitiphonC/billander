import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/bill.dart';

/// ไอคอนของบิล: ภาพที่วาดเอง > ตัวอักษรที่ตั้ง > อักษรตัวแรกของชื่อ
class BillIconBadge extends StatelessWidget {
  const BillIconBadge({
    super.key,
    required this.bill,
    this.size = 40,
  });

  final Bill bill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = Color(bill.iconColor ?? 0xFFD8EFE9);
    final foreground = Theme.of(context).colorScheme.onPrimaryContainer;

    Widget? child;
    final drawing = bill.iconDrawing;
    if (drawing != null && drawing.isNotEmpty) {
      try {
        child = ClipOval(
          child: Image.memory(
            base64Decode(drawing),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
          ),
        );
      } catch (_) {
        child = null;
      }
    }
    child ??= Text(
      bill.iconText?.trim().isNotEmpty == true
          ? bill.iconText!.trim()
          : (bill.title.trim().isEmpty ? '?' : bill.title.trim()[0]),
      style: TextStyle(
        color: foreground,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.4,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
