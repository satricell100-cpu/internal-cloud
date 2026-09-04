@echo off
title Internal Cloud - Build APK Android
color 0A
echo.
echo  ======================================================
echo     INTERNAL CLOUD - BUILD APK UNTUK HP ANDROID
echo  ======================================================
echo.
cd /d "%~dp0mobile"

echo  [1/2] Memeriksa dependensi Flutter...
call flutter pub get
if errorlevel 1 (
  echo  [X] Gagal memeriksa dependensi.
  pause
  exit /b 1
)

echo.
echo  [2/2] Sedang meng-compile APK Release... (Harap tunggu 1-2 menit)
call flutter build apk --release

if errorlevel 1 (
  echo.
  echo  [X] Build APK gagal. Periksa error di atas.
  pause
  exit /b 1
)

echo.
echo  ======================================================
echo   SUKSES! APK SIAP DIINSTAL DI HP ANDA
echo  ======================================================
echo.
echo   File APK tersimpan di:
echo   %~dp0mobile\build\app\outputs\flutter-apk\app-release.apk
echo.
echo   Membuka folder lokasi APK...
explorer /select,"%~dp0mobile\build\app\outputs\flutter-apk\app-release.apk"
echo.
pause
