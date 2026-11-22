$ErrorActionPreference = 'Stop'

$zip = 'C:\Users\ACER\AppData\Local\Temp\opencode\flutter_windows_3.50.1-stable.zip'
$dest = 'C:\src'
$flutterDir = Join-Path $dest 'flutter'
$expectedHash = '33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb'

if (-not (Test-Path $zip)) {
    throw "ไม่พบไฟล์ zip: $zip"
}

Write-Host 'ตรวจสอบ SHA256...'
$actualHash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "SHA256 ไม่ตรง! expected=$expectedHash actual=$actualHash"
}
Write-Host 'SHA256 OK'

if (Test-Path $flutterDir) {
    Write-Host 'พบ flutter อยู่แล้ว จะใช้ของเดิม'
} else {
    Write-Host 'กำลังแตกไฟล์ (1.7 GB) ...'
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    tar -xf $zip -C $dest
}

$binDir = Join-Path $flutterDir 'bin'
if (-not (Test-Path (Join-Path $binDir 'flutter.bat'))) {
    throw 'แตกไฟล์แล้วแต่ไม่พบ flutter.bat'
}

Write-Host 'เพิ่ม C:\src\flutter\bin ลง PATH ของผู้ใช้...'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike '*C:\src\flutter\bin*') {
    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        'C:\src\flutter\bin'
    } else {
        "$userPath;C:\src\flutter\bin"
    }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}

$env:Path = "$env:Path;$binDir"
Write-Host 'ตรวจสอบเวอร์ชัน...'
& (Join-Path $binDir 'flutter.bat') --version
