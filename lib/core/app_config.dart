/// ตั้งค่าเหล่านี้เก็บในตาราง settings ของ SQLite
/// เพื่อให้เปลี่ยนที่อยู่ GitHub ได้โดยไม่ต้อง build ใหม่
const String settingUpdateUrl = 'update_url';
const String settingLastUpdateCheck = 'last_update_check';
const String settingDefaultSaveAheadMonths = 'default_save_ahead_months';
const String settingDefaultSaveAheadUnit = 'default_save_ahead_unit';

/// ตัวอย่าง:
/// https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update.json
const String kUpdateJsonHelp =
    'https://raw.githubusercontent.com/<user>/<repo>/main/update.json';
