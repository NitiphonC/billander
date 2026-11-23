import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/money.dart';
import '../data/database.dart';
import '../state/app_state.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  Future<void> _editInitialBalance(BuildContext context) async {
    final amount = await showAmountDialog(
      context,
      title: 'ปรับเงินตั้งต้นในคลัง',
      initialValue: Money.toBaht(state.initialEntry?.amountSatang ?? 0)
          .toStringAsFixed(2),
      confirmLabel: 'บันทึก',
      allowZero: true,
    );
    if (amount == null || !context.mounted) return;
    await state.setInitialBalance(amount);
    if (context.mounted) {
      showMessage(context, 'เงินตั้งต้นตอนนี้ ${Money.format(state.poolSatang)}');
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: state.reminderTime,
    );
    if (picked == null) return;
    await state.updateSetting(
        settingReminderHour, picked.hour.toString());
    await state.updateSetting(
        settingReminderMinute, picked.minute.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalOverrides =
        state.bills.where((b) => b.saveAheadMonths != null).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'ตั้งค่า',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'คลังเงิน',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Money.format(state.initialEntry?.amountSatang ?? 0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'เงินตั้งต้น + เก็บ − ใช้ − จ่าย = เงินในคลัง\n'
                  'ปรับได้เมื่อต้องการเติม/ลดเงินในคลังเอง',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editInitialBalance(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('ปรับเงินตั้งต้น'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'ลิมิตเก็บล่วงหน้า',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ค่าตั้งต้น: ${state.defaultSaveAheadMonths} เดือน',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'บิลที่อยู่ไกลกว่าช่วงนี้จะยังไม่นำมาคำนวณยอดรายวัน '
                  'ช่วยไม่ให้ยอดเก็บวันแรก ๆ สูงเกินไป '
                  '(บางบิลตั้งแยกได้ในหน้าแก้บิล)',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showTextDialog(
                      context,
                      title: 'เก็บล่วงหน้าได้กี่เดือน',
                      initialValue: state.defaultSaveAheadMonths.toString(),
                      label: 'จำนวนเดือน',
                    );
                    if (value == null) return;
                    final months = int.tryParse(value.trim());
                    if (months == null || months < 1) {
                      if (context.mounted) {
                        showMessage(context, 'กรอกจำนวนเดือนให้ถูกต้อง');
                      }
                      return;
                    }
                    await state.updateSetting(
                      settingDefaultSaveAheadMonths,
                      months.toString(),
                    );
                    if (context.mounted) {
                      showMessage(context, 'ตั้งค่าลิมิตเป็น $months เดือนแล้ว');
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('เปลี่ยนค่าตั้งต้น'),
                ),
                if (finalOverrides.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'บิลที่ตั้งแยกไว้ (ไม่ตามค่าตั้งต้น)',
                    style: theme.textTheme.labelLarge,
                  ),
                  for (final bill in finalOverrides)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(bill.title)),
                          Text('${bill.saveAheadMonths} เดือน'),
                        ],
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'ยังไม่มีบิลที่ตั้งแยก — ทุกบิลใช้ค่าตั้งต้น',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'แจ้งเตือนรายวัน',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('เปิดแจ้งเตือน'),
                  subtitle: const Text('บอกยอดที่ต้องเก็บวันนี้'),
                  value: state.notificationsEnabled,
                  onChanged: (value) => state.updateSetting(
                    settingNotifications,
                    value.toString(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('เวลาแจ้งเตือน'),
                  subtitle: Text(
                    '${state.reminderTime.hour.toString().padLeft(2, '0')}:'
                    '${state.reminderTime.minute.toString().padLeft(2, '0')} น.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickReminderTime(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'อัปเดตแอพ (ไม่เสียเงิน)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.updateUrl.isEmpty
                      ? 'ยังไม่ได้ตั้งค่าที่อยู่ update.json'
                      : state.updateUrl,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'ตัวอย่าง: $kUpdateJsonHelp',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showTextDialog(
                      context,
                      title: 'ที่อยู่ update.json',
                      initialValue: state.updateUrl,
                      label: 'https://...',
                    );
                    if (value == null) return;
                    await state.updateSetting(settingUpdateUrl, value);
                    if (context.mounted) {
                      showMessage(context, 'บันทึกที่อยู่อัปเดตแล้ว');
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('ตั้งค่าที่อยู่อัปเดต'),
                ),
                OutlinedButton.icon(
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
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('ตรวจสอบอัปเดตตอนนี้'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'วิธีคำนวณ',
            child: Text(
              '• ทุกบิลมีวันจ่ายของตัวเอง\n'
              '• วันที่เหลือ = วันจ่าย − วันนี้ + 1 (นับรวมสองวัน)\n'
              '• เงินในคลังจะไปหักบิลที่ใกล้กำหนดที่สุดก่อน\n'
              '• ยอดที่ต้องเก็บต่อวันของแต่ละบิล = '
              'ยอดที่ยังไม่มีคลังรับรอง ÷ วันที่เหลือ (ปัดขึ้น)\n'
              '• ยอดที่แสดง = ผลบวกของทุกบิล\n'
              '• ถ้าผ่านไปหนึ่งวันโดยไม่บันทึก วันที่เหลือจะลดลง '
              'และยอดต่อวันจะเพิ่มขึ้นอัตโนมัติ\n'
              '• กดจ่ายบิลได้ก็ต่อเมื่อเงินในคลังพอจ่ายบิลนั้น',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
