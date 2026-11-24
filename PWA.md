# แจกแอพให้ iPhone (และทุกคน) แบบฟรี — PWA

แอพเว็บนี้ใช้โค้ดเดียวกับแอพมือถือ แต่เปลี่ยนที่เก็บข้อมูลจาก SQLite เป็น `SharedPreferences` (localStorage ของเบราว์เซอร์) อัตโนมัติผ่าน `AppStorage`

## สร้างไฟล์เว็บ

```powershell
flutter build web --release --base-href=/<ชื่อ-repo>/
```

เช่น repo ชื่อ `billander` → `--base-href=/billander/`

ผลลัพธ์อยู่ที่ `build\web\` (มี `index.html`, `flutter_bootstrap.js`, `main.dart.js`, `manifest.json`, `icons/`)

## ขึ้น GitHub Pages (ฟรี)

**วิธีที่แนะนำ: ให้ GitHub Actions build + deploy ให้เอง (ไม่ต้อง commit ไฟล์ build)**

1. สร้าง repo บน GitHub (public) ชื่ออะไรก็ได้ เช่น `billander`
2. push โค้ดขึ้น repo (มี `.github/workflows/deploy.yml` อยู่แล้ว)
3. ไปที่ repo → **Settings** → **Pages** → Source: **GitHub Actions** → Save
4. กด **Actions** → เลือก workflow "Deploy PWA to GitHub Pages" → **Run workflow** (หรือ push ครั้งหน้าก็รันอัตโนมัติ)
5. เมื่อเสร็จ จะได้ลิงก์
   ```
   https://<ชื่อผู้ใช้>.github.io/<ชื่อ-repo>/
   ```
   (workflow ใช้ `--base-href=/<ชื่อ-repo>/` ให้ตรงกับ repo อัตโนมัติ)
6. ส่งลิงก์นี้ให้คนใช้ iPhone → เปิดใน **Safari** → ปุ่ม Share → **Add to Home Screen** → ได้ไอคอนแอพหน้า Home

## อัปเดตครั้งต่อไป

1. แก้โค้ด → commit + push
2. GitHub Actions build + deploy ให้เอง
3. ฝั่งผู้ใช้: เปิดแอพแล้วรีเฟรช (ถ้า cache ค้าง ให้ปิดแท็บแล้วเปิดใหม่)

## ข้อควรรู้

- ข้อมูลเก็บใน **localStorage ของเบราว์เซอร์/อุปกรณ์นั้น** — คนละเครื่องคนละข้อมูล (แอพไม่มีระบบซิงก์/ส่งข้อมูลออกเลย ตาม `PRIVACY.md`)
- ไม่มีแจ้งเตือนรายวันบนเว็บ (plugin ไม่รองรับ) — ระบบคำนวณยังทำงานปกติ
- ระบบอัปเดตผ่าน `update.json` เป็นของ Android; เว็บอัปเดตผ่าน GitHub Pages ทันทีที่ push
- `base-href` ต้องตรงกับชื่อ repo เสมอ มิเช่นนั้นจะเจอ 404 (`flutter_bootstrap.js` ไม่โหลด)
- ทดสอบ lokal ก่อนอัปโหลดได้ด้วย:
  ```powershell
  python -m http.server 8081 --directory C:\Users\ACER\AppData\Local\Temp\opencode\webroot
  # เปิด http://localhost:8081/billandar/
  ```

## ผลที่ตรวจแล้ว

- `flutter build web --release --base-href=/billandar/` → สำเร็จ
- เปิดผ่าน local server ที่ path `/billandar/` → หน้าแอพแสดงถูกต้อง (ฟอนต์ Prompt, ไม่มี emoji, ไม่มีข้อความแดง)
- `flutter test` → 49 passed (รวม `web_storage_test.dart` ทดสอบ CRUD บน SharedPreferences)
- `flutter analyze` → No issues found
