@echo off
title Internal Cloud - Build APK
echo.
echo  ============================================
echo   Internal Cloud - Build APK Android
echo  ============================================
echo.
cd /d "%~dp0"

REM Pastikan Flutter ada di PATH
where flutter >nul 2>&1
if errorlevel 1 (
  echo  [!] Flutter tidak ditemukan di PATH.
  echo      Pastikan flutter sudah diinstall dan path-nya benar.
  pause
  exit /b 1
)

echo  Running flutter pub get...
call flutter pub get
if errorlevel 1 (
  echo  [X] Gagal flutter pub get.
  pause
  exit /b 1
)

echo.
echo  Building APK release... (ini bisa makan waktu beberapa menit)
call flutter build apk --release

if errorlevel 1 (
  echo.
  echo  [X] Build gagal. Lihat pesan error di atas.
  pause
  exit /b 1
)

echo.
echo  ============================================
echo   BUILD SUKSES!
echo.
echo   Lokasi APK:
echo   %~dp0build\app\outputs\flutter-apk\app-release.apk
echo.
echo   Kirim APK ke HP untuk diinstall.
echo  ============================================
echo.
pause
