@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

:: ===============================
:: Параметры
:: ===============================
set "FRAMEWORK_URL=https://go.microsoft.com/fwlink/?LinkId=2088631"
set "FRAMEWORK_FILE=%TEMP%\ndp48-x86-x64-allos-enu.exe"
set "FTP_URL=ftp://rustdesk.olservice.ru/files/ndp48-x86-x64-allos-enu.exe"
set "FTP=ftp://rustdesk.olservice.ru/files"
set "USER=olservice"
set "PASS=Пампам123"

echo.
echo ========================================
echo CHECK .NET 4.8
echo ========================================
set "NET48_INSTALLED=0"

for /f "tokens=3" %%A in (
    'reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul ^| find "Release"'
) do (
    if %%A GEQ 528040 set "NET48_INSTALLED=1"
)

if "%NET48_INSTALLED%"=="1" (
    echo .NET 4.8 already installed
) else (
    echo Installing .NET 4.8...

    :: 1. FTP (основной)
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP_URL%','%FRAMEWORK_FILE%') } catch { }"

    :: 2. Microsoft (fallback + FIX TLS)
    if not exist "%FRAMEWORK_FILE%" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%FRAMEWORK_URL%' -OutFile '%FRAMEWORK_FILE%' -ErrorAction Stop } catch { }"
    )

    :: 3. Финальная проверка
    if not exist "%FRAMEWORK_FILE%" (
        echo ERROR: Failed to download .NET 4.8
        goto :CLEANUP
    )

    :: 4. Установка
    start /wait "" "%FRAMEWORK_FILE%" /quiet /norestart

    if errorlevel 1 (
        echo ERROR: .NET 4.8 installation failed
        goto :CLEANUP
    )
)

:CLEANUP

:: ===============================
:: Включаем защиту
:: ===============================
netsh advfirewall set allprofiles state on >nul 2>&1
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1

echo Все операции завершены.

echo Закрытие через 10 секунд...
timeout /t 10 /nobreak >nul
exit