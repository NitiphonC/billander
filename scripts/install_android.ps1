$ErrorActionPreference = 'Stop'

$tmp = 'C:\Users\ACER\AppData\Local\Temp\opencode'
$jdkZip = Join-Path $tmp 'jdk17.zip'
$toolsZip = Join-Path $tmp 'cmdline-tools.zip'
$srcRoot = 'C:\src'
$jdkRoot = Join-Path $srcRoot 'jdk-17'
$sdkRoot = 'C:\Users\ACER\AppData\Local\Android\Sdk'
$cmdRoot = Join-Path $sdkRoot 'cmdline-tools'
$sdkmanager = Join-Path $cmdRoot 'latest\bin\sdkmanager.bat'
$avdmanager = Join-Path $cmdRoot 'latest\bin\avdmanager.bat'

# ---------- JDK 17 ----------
if (-not (Test-Path (Join-Path $jdkRoot 'bin\java.exe'))) {
    Write-Host 'แตกไฟล์ JDK 17...'
    New-Item -ItemType Directory -Path $srcRoot -Force | Out-Null
    tar -xf $jdkZip -C $srcRoot
    $extracted = Get-ChildItem $srcRoot -Directory -Filter 'jdk-17*' |
        Where-Object { $_.Name -ne 'jdk-17' } | Select-Object -First 1
    if (-not $extracted) { throw 'ไม่พบโฟลเดอร์ JDK หลังแตกไฟล์' }
    if (Test-Path $jdkRoot) { Remove-Item $jdkRoot -Recurse -Force }
    Rename-Item $extracted.FullName 'jdk-17'
}
$env:JAVA_HOME = $jdkRoot
$env:Path = "$jdkRoot\bin;$env:Path"
Write-Host 'JAVA_HOME =' $env:JAVA_HOME
& java -version

# ---------- Android cmdline-tools ----------
if (-not (Test-Path $sdkmanager)) {
    Write-Host 'แตกไฟล์ Android cmdline-tools...'
    New-Item -ItemType Directory -Path $cmdRoot -Force | Out-Null
    tar -xf $toolsZip -C $cmdRoot
    $inner = Join-Path $cmdRoot 'cmdline-tools'
    if (Test-Path $inner) {
        $latest = Join-Path $cmdRoot 'latest'
        if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
        Move-Item $inner $latest
    }
}
if (-not (Test-Path $sdkmanager)) { throw 'ไม่พบ sdkmanager.bat' }

Write-Host 'ยอมรับ Android SDK licenses...'
1..100 | ForEach-Object { 'y' } | & $sdkmanager --licenses | Out-Null

Write-Host 'ติดตั้ง platform-tools / platform 36 / build-tools / emulator / image API 35...'
$installLog = Join-Path $tmp 'android_sdk_install.log'
& $sdkmanager --install 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'emulator' 'system-images;android-35;google_apis;x86_64' 2>&1 | Tee-Object -FilePath $installLog | Out-Null
if ($LASTEXITCODE -ne 0) {
    Get-Content $installLog -Tail 40
    throw "sdkmanager install ล้มเหลว (exit $LASTEXITCODE)"
}
Write-Host 'ติดตั้งแพ็กเกจ Android SDK สำเร็จ'

# ---------- AVD ----------
Write-Host 'สร้าง AVD billandar_pixel6 ...'
1..10 | ForEach-Object { '' } | & $avdmanager create avd --name billandar_pixel6 --package 'system-images;android-35;google_apis;x86_64' --device 'pixel_6' --force 2>&1 | Out-Null

# ---------- env vars (ถาวร) ----------
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkRoot, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkRoot, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkRoot, 'User')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($p in @("$jdkRoot\bin", "$sdkRoot\platform-tools", "$cmdRoot\latest\bin", "$sdkRoot\emulator")) {
    if ($userPath -notlike "*$p*") { $userPath = "$userPath;$p" }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
Write-Host 'ตั้ง JAVA_HOME / ANDROID_HOME / PATH แล้ว'

# ---------- flutter config ----------
& 'C:\src\flutter\bin\flutter.bat' config --android-sdk $sdkRoot
Write-Host 'เสร็จสิ้น'
