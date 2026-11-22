$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'ไม่พบ flutter ใน PATH กรุณาติดตั้ง Flutter SDK ก่อน'
}

if (-not (Test-Path 'android') -or -not (Test-Path 'ios')) {
  Write-Host 'สร้างโฟลเดอร์ platform...'
  flutter create . --project-name billandar --org com.billandar --platforms android,ios
}

Write-Host 'โหลดแพ็กเกจ...'
flutter pub get

Write-Host 'รันทดสอบสูตรคำนวณ...'
flutter test

Write-Host 'พร้อมรันแล้ว: flutter run'
