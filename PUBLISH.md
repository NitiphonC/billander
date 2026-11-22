# เผยแพร่แบบฟรี + อัปเดตบ่อย (ไม่ขึ้น Store)

แอพเช็กอัปเดตจากไฟล์ `update.json` ที่วางบน GitHub raw → ถ้า `versionCode` ในไฟล์มากกว่าของที่ติดตั้งอยู่ จะโชว์แถบแจ้งเตือนในหน้าภาพรวม กดแล้วเปิดเบราว์เซอร์โหลด APK ให้ผู้ใช้ติดตั้งเอง

## ครั้งแรก (ทำครั้งเดียว)

1. **build release**
   ```powershell
   flutter build apk --release --split-per-abi
   ```
   ไฟล์ที่ได้ใน `build\app\outputs\flutter-apk\`:
   - `app-arm64-v8a-release.apk` ← มือถือส่วนใหญ่ (ส่งตัวนี้)
   - `app-armeabi-v7a-release.apk`
   - `app-x86_64-release.apk` ( emulator )

2. **สร้าง GitHub repo (public ก็ได้ ฟรี)** เช่น `billandar`

3. **อัปโหลด APK ขึ้น Releases**
   - กด Releases → Draft a new release
   - Tag: `v0.1.1`
   - แนบไฟล์ `app-arm64-v8a-release.apk`
   - Publish release → copy ลิงก์-download ของ APK

4. **สร้างไฟล์ `update.json`** ใน repo (แก้จากตัวอย่างในโปรเจกต์นี้):
   ```json
   {
     "versionCode": 2,
     "versionName": "0.1.1",
     "apkUrl": "https://github.com/<user>/<repo>/releases/download/v0.1.1/app-arm64-v8a-release.apk",
     "notes": "ปรับฟอนต์ Prompt, ถอด emoji"
   }
   ```
   `versionCode` ต้อง **มากกว่า** build number ต่อท้าย `version` ใน `pubspec.yaml` (ตอนนี้ `0.1.0+1` → code = 1)

5. **ได้ raw URL** แบบนี้:
   ```
   https://raw.githubusercontent.com/<user>/<repo>/main/update.json
   ```
   (เปลี่ยน `main` เป็น `master` ถ้า branch หลักของคุณชื่อ master)

6. **ในแอพ**: แท็บตั้งค่า → "อัปเดตแอพ (ไม่เสียเงิน)" → "ตั้งค่าที่อยู่อัปเดต" → วาง raw URL → บันทึก

## ทุกครั้งที่มีเวอร์ชันใหม่

1. แก้ `version` ใน `pubspec.yaml` เช่น `0.1.1+2`
2. `flutter build apk --release --split-per-abi`
3. สร้าง Release ใหม่ (tag `v0.1.1`) + แนบ APK ตัวใหม่
4. แก้ `update.json`: `versionCode`, `versionName`, `apkUrl`, `notes`
5. ผู้ใช้จะเห็นแถบแจ้งเตือนในแอพภายใน 12 ชม. (หรือกด "ตรวจสอบอัปเดตตอนนี้" ในตั้งค่า)

## ข้อควรรู้

- Release APK ที่ build ตอนนี้ยังเซ็นด้วย **debug key** (เพราะ `build.gradle.kts` ตั้งไว้) — ติดตั้ง/อัปเดตผ่าน APK ตรงได้ปกติ แต่ถ้าจะขึ้น Play ต้องสร้าง upload keystore เพิ่ม
- Flutter 3.50 แจ้งเตือนว่า `package_info_plus` ยังใช้ Kotlin Gradle Plugin แบบเก่า (build ผ่าน แต่เวอร์ชัน Flutter อนาคตอาจต้องอัปเกรดแพ็กเกจ)

- ผู้ใช้ต้องอนุญาต **Install unknown apps** ให้เบราว์เซอร์ครั้งแรก (Android จะถามตอนกด install)
- ถ้าเปลี่ยนเป็น private repo → raw URL จะใช้ไม่ได้ ให้ใช้ public repo หรือ host ไฟล์เอง
- ระบบนี้ **ไม่ต้องจ่ายเงิน** และอัปเดตได้ไม่จำกัดครั้ง
- ไม่รองรับ iOS (ต้อง Mac + Apple Developer $99/ปี)
- ถ้าอยากขึ้น Google Play ภายหลัง ต้องเปลี่ยน package name และสร้าง upload keystore เพิ่ม

## ไฟล์ที่เกี่ยวข้อง

- `lib/services/update_service.dart` — อ่าน manifest + เปิดลิงก์ APK
- `lib/state/app_state.dart` — เก็บ URL / เช็กอัปเดต / เก็บผล
- `lib/ui/settings_screen.dart` — ตั้งค่า URL
- `lib/ui/dashboard_screen.dart` — แถบแจ้งเวอร์ชันใหม่
- `update.json` — ตัวอย่าง manifest
