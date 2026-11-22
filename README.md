# Billandar

แอพมือถือ (Flutter) สำหรับวางแผนเก็บเงินรายวันให้ **พอจ่ายบิลพอดีตามวันจ่าย** แบบ "กองกลางกองเดียว"

## สิ่งที่ทำได้

- ป้อนบิลพร้อมวันจ่าย แบบครั้งเดียวหรือซ้ำทุกเดือน (สร้างล่วงหน้า 12 เดือน)
- แสดง **ยอดที่ต้องเก็บวันนี้** = ผลบวกของยอดต่อวันของทุกบิลที่ยังไม่จ่าย
- บันทึก "เก็บวันนี้" / "เอาเงินจากคลังไปใช้"
- กดยืนยัน "จ่ายบิลแล้ว" ได้ก็ต่อเมื่อเงินในคลังพอ (ปรับเงินตั้งต้นเองได้)
- เมื่อผ่านไปหนึ่งวันโดยไม่บันทึก ระบบคำนวณใหม่ทันที → ยอดต่อวันเพิ่มขึ้น
- ปฏิทินรายเดือน + ประวัติรายวัน + แจ้งเตือนรายวัน
- เก็บในเครื่องด้วย SQLite (Android) / localStorage (เว็บ) — ไม่มีคลาวด์ ไม่ส่งข้อมูลออก

## สูตรคำนวณ (ตามที่ยืนยัน)

```
หลักการ: คลังกองเดียว = เงินตั้งต้น + รวมเก็บ − รวมใช้ − รวมจ่าย

1) เรียงบิลที่ยังไม่จ่ายตามวันจ่าย (ใกล้สุดก่อน)
2) เงินในคลังไปหักบิลใกล้กำหนดก่อน (FIFO) จนหมดคลัง
3) สำหรับแต่ละบิล:
     n = วันจ่าย − วันนี้ + 1        (นับรวมวันนี้และวันจ่าย)
     ถ้าเลยกำหนดแล้ว n = 1 พร้อมแจ้ง overdue
     ต้องเก็บ/วัน = ceil((amount − ส่วนที่คลังรับรอง) / n)  [หน่วยสตางค์]
4) ยอดที่โชว์ = ผลบวกของทุกบิล
```

ตัวอย่างที่ยืนยัน: วันที่ 1 บิล A 100 บาท จ่ายวันที่ 10, บิล B 100 บาท จ่ายวันที่ 20 → เก็บวันละ 10 + 5 = **15 บาท** พอถึงวันที่ 10 กดจ่าย A ระบบตัด A ออก → เหลือเก็บวันละ 5 บาทของ B

## UI / ฟอนต์

- ฟอนต์ **Prompt** (Google Fonts, Thai + Latin) ฝังอยู่ใน `assets/fonts/` พร้อมไฟล์ license `OFL.txt` — ไม่ต้องโหลดตอนรัน
- ไม่ใช้ emoji ในข้อความของแอพ

## เผยแพร่ / อัปเดตแบบฟรี

- **Android**: ดู `PUBLISH.md` — แจก release APK ผ่าน GitHub Releases + เช็กอัปเดตอัตโนมัติจาก `update.json`
- **iPhone / ทุกแพลตฟอร์ม**: ดู `PWA.md` — build เว็บแจกลิงก์ GitHub Pages ฟรี เปิดใน Safari แล้ว Add to Home Screen
- ทั้งสองทางไม่ต้องจ่าย Play $25 หรือ Apple $99
- ที่เก็บข้อมูลแยกตาม storage: `lib/data/storage.dart` (SQLite บนมือถือ / SharedPreferences บนเว็บ)

## วิธีรัน

ติดตั้งแล้วในเครื่องนี้:

- Flutter 3.50.1 / Dart 3.14 → `C:\src\flutter\bin`
- JDK 17 (Temurin) → `C:\src\jdk-17`
- Android SDK 36 + emulator image API 35 → `%LOCALAPPDATA%\Android\Sdk`
- AVD ชื่อ `billandar_pixel6`
- `flutter doctor` ผ่าน (Android toolchain ✅)

```powershell
flutter test                                                      # 47 unit/widget tests
flutter test integration_test/app_test.dart -d emulator-5554      # 2 integration tests
flutter analyze                                                   # No issues found
flutter emulators --launch billandar_pixel6
flutter run
```

ดูกรณีทดสอบละเอียดทั้งหมดได้ใน `TEST_CASES.md` (49 automatic + 10 manual + 7 visual)

หมายเหตุแจ้งเตือน: ถ้าอุปกรณ์ไม่อนุญาต exact alarm ระบบจะใช้การแจ้งเตือนแบบ inexact แทน และจะไม่โชว์ข้อความ error technical ในหน้าแอพ

> หลังรัน integration test ต้องรัน `flutter build apk --debug` ใหม่อีกครั้ง เพราะคำสั่งนั้นเขียนทับ `app-debug.apk` ด้วย APK ของตัวทดสอบ (ถ้า install ตัวนั้นจะเห็นแต่ spinner สีฟ้าค้างอยู่)

หากเปิด Terminal ใหม่แล้ว `flutter` ไม่เจอ ให้เพิ่ม `C:\src\flutter\bin` ลง PATH (สคริปต์ติดตั้งเพิ่มให้แล้ว หรือรัน `scripts\install_flutter.ps1`)

หมายเหตุ build: `android/app/build.gradle.kts` ได้เปิด `isCoreLibraryDesugaringEnabled = true` และเพิ่ม `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")` เพราะ `flutter_local_notifications` ต้องการ — อย่าลบออกมิเช่นนั้น build จะล้มเหลว

> ถ้าแจ้งเตือนไม่ขึ้นบน Android 13+ ให้เพิ่ม
> `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
> ลงใน `android/app/src/main/AndroidManifest.xml` (เหนือ `<application>`)

## ความปลอดภัย / ความเป็นส่วนตัว

อ่าน `PRIVACY.md` — แอพไม่มี Firebase/Analytics/โฆษณา ไม่ส่งข้อมูลการเงินออกจากเครื่อง และลบโค้ดที่ `print` ข้อมูลออกแล้ว

## โครงสร้าง

```
lib/
  core/         date_utils.dart, money.dart, calculator.dart  <- สูตรคำนวณอยู่ที่นี่
  models/       bill.dart, ledger_entry.dart
  data/         database.dart (SQLite)
  state/        app_state.dart (business logic ทั้งหมด)
  services/     notification_service.dart, update_service.dart
  ui/           dashboard, calendar, bills, history, settings
test/
  calculator_test.dart   <- ทดสอบตามตัวอย่างที่ยืนยัน
```
