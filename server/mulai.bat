@echo off
title Internal Cloud Server
echo.
echo  ============================================
echo   Internal Cloud Server - Chat Based Storage
echo  ============================================
echo.

cd /d "%~dp0"

REM Cek apakah node_modules sudah terpasang
if not exist "node_modules" (
  echo  [!] node_modules belum ada. Menginstall dependencies...
  echo.
  call npm install
  if errorlevel 1 (
    echo.
    echo  [X] Gagal menginstall dependencies. Pastikan Node.js terpasang.
    pause
    exit /b 1
  )
)

if not exist "data" mkdir data
if not exist "data\uploads" mkdir data\uploads
if not exist "data\quarantine" mkdir data\quarantine

echo  Menjalankan server... (tekan Ctrl+C untuk berhenti)
echo  Akses API di: http://localhost:3000
echo  Health check:  http://localhost:3000/api/health
echo.
node src/index.js

pause
