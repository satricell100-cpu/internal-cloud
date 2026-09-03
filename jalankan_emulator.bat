@echo off
echo Membersihkan lock file lama jika ada...
del /f /q "%USERPROFILE%\.android\avd\tanilink_emulator.avd\*.lock" 2>nul
rmdir /s /q "%USERPROFILE%\.android\avd\tanilink_emulator.avd\hardware-qemu.ini.lock" 2>nul
rmdir /s /q "%USERPROFILE%\.android\avd\tanilink_emulator.avd\multiinstance.lock" 2>nul

echo Menjalankan Android Emulator...
start "" "C:\Android\emulator\emulator.exe" -avd tanilink_emulator
echo Emulator sedang dibuka di jendela terpisah!
