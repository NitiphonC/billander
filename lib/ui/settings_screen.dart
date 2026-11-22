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
            title: 'ซิงก์คลาวด์ (Firebase)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('เปิดซิงก์'),
                  subtitle: Text(
                    state.syncConfigured
                        ? 'ข้อมูลซิงก์ผ่าน Firebase'
                        : 'ยังไม่ได้เชื่อม Firebase → เก็บในเครื่องก่อน',
                  ),
                  value: state.syncEnabled,
                  onChanged: (value) => state.updateSetting(
                    settingSyncEnabled,
                    value.toString(),
                  ),
                ),
                if (state.syncEnabled && !state.syncConfigured)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'หากต้องการซิงก์: รัน flutterfire configure แล้วส่ง '
                      'FirebaseSyncService เข้า BillandarApp ใน main.dart',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!state.syncEnabled || !state.syncConfigured) {
                      showMessage(context, 'ยังไม่ได้เปิดซิงก์คลาวด์');
                      return;
                    }
                    await state.syncNow();
                    if (context.mounted) {
                      showMessage(
                        context,
                        state.error ?? 'ซิงก์ข้อมูลเสร็จแล้ว',
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('ซิงก์ตอนนี้'),
                ),
                if (state.lastSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'ล่าสุด: ${state.lastSyncAt}',
                      style: theme.textTheme.bodySmall,
                    ),
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
