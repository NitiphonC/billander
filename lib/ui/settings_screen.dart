import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/money.dart';
import '../data/database.dart';
import '../models/bill.dart';
import '../state/app_state.dart';
import 'design_system.dart';
import 'widgets/common.dart';
import 'widgets/info_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  Future<void> _editPoolBalance(BuildContext context) async {
    final amount = await showAmountDialog(
      context,
      title: 'ปรับเงินในคลัง',
      initialValue: Money.toBaht(state.poolSatang).toStringAsFixed(2),
      confirmLabel: 'บันทึก',
      allowZero: true,
    );
    if (amount == null || !context.mounted) return;
    await state.setPoolBalance(amount);
    if (context.mounted) {
      showMessage(context, 'เงินในคลังตอนนี้ ${Money.format(state.poolSatang)}');
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
        padding: AppSpace.screenPadding,
        children: [
          Text(
            'ตั้งค่า',
            style: AppType.headline(context),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'คลังเงิน',
            action: const AppInfoButton(
              title: 'คลังเงินคืออะไร',
              body: 'เงินที่คุณเก็บไว้แล้ว ตรงกับคำว่า "ในคลัง" ในหน้าภาพรวม\n\n'
                  'แอปจะนำเงินนี้ไปหักบิลที่ใกล้กำหนดที่สุดก่อน '
                  'ส่วนที่ยังไม่พอจะกลายเป็นยอดที่ต้องเก็บเพิ่ม\n\n'
                  'กด "ปรับเงินในคลัง" เพื่อแก้จำนวนได้โดยตรง '
                  'ประวัติการเก็บ/ใช้/จ่ายเดิมยังอยู่ครบทุกรายการ',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Money.format(state.poolSatang),
                  style: AppType.headline(context)
                      .copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'ตรงกับ "ในคลัง" ในหน้าภาพรวม · แก้ได้ที่ปุ่มด้านล่าง',
                  style: AppType.caption(context),
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => _editPoolBalance(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('ปรับเงินในคลัง'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'ระยะเก็บล่วงหน้า (ค่าตั้งต้น)',
            action: const AppInfoButton(
              title: 'ระยะเก็บล่วงหน้าคืออะไร',
              body: 'แอปจะเริ่มบอกให้เก็บล่วงหน้านานแค่ไหนก่อนวันจ่าย '
                  '(นับวันจ่ายเป็น 1 วันด้วย)\n\n'
                  '• ตั้ง 1 วัน = โชว์ยอดเฉพาะวันจ่าย\n'
                  '• ตั้ง 7 วัน = โชว์ 7 วันสุดท้ายก่อนจ่าย (วันจ่าย + อีก 6 วัน)\n\n'
                  'บิลที่อยู่ไกลกว่าช่วงนี้ยังไม่นำมาคำนวณยอดรายวัน '
                  'แต่ตั้งแยกได้ในหน้าแก้บิล',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ค่าตั้งต้น: ${state.defaultSaveAheadMonths} '
                  '${state.defaultSaveAheadUnit.label}',
                  style: AppType.title(context)
                      .copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'นับวันจ่ายเป็น 1 วัน · บิลที่อยู่ไกลกว่าช่วงนี้ยังไม่เก็บ',
                  style: AppType.caption(context),
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await showSaveAheadDialog(
                      context,
                      initialValue: state.defaultSaveAheadMonths,
                      initialUnit: state.defaultSaveAheadUnit,
                    );
                    if (result == null) return;
                    await state.updateSetting(
                      settingDefaultSaveAheadMonths,
                      result.value.toString(),
                    );
                    await state.updateSetting(
                      settingDefaultSaveAheadUnit,
                      result.unit.storageName,
                    );
                    if (context.mounted) {
                      showMessage(
                        context,
                        'ตั้งค่าลิมิตเป็น ${result.value} ${result.unit.label}แล้ว',
                      );
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('เปลี่ยนค่าตั้งต้น'),
                ),
                if (finalOverrides.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'บิลที่ตั้งแยกไว้ (ไม่ตามค่าตั้งต้น)',
                    style: AppType.label(context),
                  ),
                  for (final bill in finalOverrides)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, size: 14),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(child: Text(bill.title)),
                          Text(
                            '${bill.saveAheadMonths} '
                            '${(bill.saveAheadUnit ?? SaveAheadUnit.months).label}',
                          ),
                        ],
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: Text(
                      'ยังไม่มีบิลที่ตั้งแยก — ทุกบิลใช้ค่าตั้งต้น',
                      style: AppType.caption(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'แจ้งเตือนรายวัน',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('เปิดแจ้งเตือน',
                      style: AppType.rowTitle(context)),
                  subtitle: Text('บอกยอดที่ต้องเก็บวันนี้',
                      style: AppType.rowSubtitle(context)),
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
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'อัปเดตแอพ (ไม่เสียเงิน)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.updateUrl.isEmpty
                      ? 'ยังไม่ได้ตั้งค่าที่อยู่ update.json'
                      : state.updateUrl,
                  style: AppType.caption(context),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'ตัวอย่าง: $kUpdateJsonHelp',
                  style: AppType.caption(context),
                ),
                const SizedBox(height: AppSpace.sm),
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
                const SizedBox(height: AppSpace.sm),
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
          const SizedBox(height: AppSpace.md),
          const SectionCard(
            title: 'วิธีคำนวณ',
            action: AppInfoButton(
              title: 'แอปจะคำนวณยังไง',
              body: '• ทุกบิลมีวันจ่ายของตัวเอง\n'
                  '• วันที่เหลือ = วันจ่าย − วันนี้ + 1 (นับรวมสองวัน)\n'
                  '• เงินในคลังจะไปหักบิลที่ใกล้กำหนดที่สุดก่อน\n'
                  '• ยอดที่ต้องเก็บต่อวันของแต่ละบิล = '
                  'ยอดที่ยังไม่มีคลังรับรอง ÷ วันที่เหลือ (ปัดขึ้น)\n'
                  '• ยอดที่แสดง = ผลบวกของทุกบิล\n'
                  '• ถ้าผ่านไปหนึ่งวันโดยไม่บันทึก วันที่เหลือจะลดลง '
                  'และยอดต่อวันจะเพิ่มขึ้นอัตโนมัติ\n'
                  '• กดจ่ายบิลได้ก็ต่อเมื่อเงินในคลังพอจ่ายบิลนั้น',
            ),
          ),
        ],
      ),
    );
  }
}
