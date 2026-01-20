@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ===============================
:: Параметры
:: ===============================
set "FRAMEWORK_URL=https://go.microsoft.com/fwlink/?LinkId=2088631"
set "FRAMEWORK_FILE=%TEMP%\ndp48-x86-x64-allos-enu.exe"

set "MSI_URL=https://честныйзнак.рф/upload/regime-1.5.1-523.msi"
set "MSI_FILE=regime.msi"

:: ===============================
:: Удаление старой версии
:: ===============================
echo Проверяем наличие старой версии Честного ЗНАК модуля...

set "OLD_PRODUCT_CODE="

:: Поиск в обычном реестре
for /f "tokens=2 delims={}" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "regime" ^| findstr /i "{"') do (
    if not defined OLD_PRODUCT_CODE set "OLD_PRODUCT_CODE={%%A}"
)

:: Поиск в WOW6432Node
for /f "tokens=2 delims={}" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "regime" ^| findstr /i "{"') do (
    if not defined OLD_PRODUCT_CODE set "OLD_PRODUCT_CODE={%%A}"
)

if defined OLD_PRODUCT_CODE (
    echo Найдена установленная старая версия: %OLD_PRODUCT_CODE%
    echo Удаляем старый модуль...
    msiexec /x %OLD_PRODUCT_CODE% /qn /norestart
    echo Старый модуль удалён.
) else (
    echo Старая версия не найдена.
)

:: ===============================
:: Выключаем Firewall и Defender
:: ===============================
echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1

:: ===============================
:: Проверка .NET Framework 4.8
:: ===============================
set "RegKey=HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
set "VersionValue=Release"

for /f "tokens=3" %%A in ('reg query "%RegKey%" /v "%VersionValue%" 2^>nul') do set Release=%%A

if not defined Release (
    echo .NET Framework 4.8 не установлен. Запускаем установку...
    goto InstallFramework
)

if %Release% GEQ 528040 (
    echo .NET Framework 4.8 установлен.
    goto MSIInstall
) else (
    echo Установлена версия ниже 4.8: Release=%Release%. Запускаем установку...
    goto InstallFramework
)

:: ===============================
:: Установка .NET Framework 4.8
:: ===============================
:InstallFramework
if not exist "%FRAMEWORK_FILE%" (
    echo Скачивание .NET Framework 4.8...
    curl -L -o "%FRAMEWORK_FILE%" "%FRAMEWORK_URL%" --retry 3 --progress-bar
    if errorlevel 1 (
        echo Ошибка скачивания Framework!
        pause
        exit /b 1
    )
)

echo Запуск установки .NET Framework 4.8...
"%FRAMEWORK_FILE%" /qb /norestart /log "%~dp0framework_install_log.txt"
set FRAMEWORK_RESULT=%ERRORLEVEL%

if %FRAMEWORK_RESULT%==0 (
    echo .NET Framework успешно установлен.
) else if %FRAMEWORK_RESULT%==3010 (
    echo Требуется перезагрузка для завершения установки Framework.
    shutdown /r /t 5
    exit
) else if %FRAMEWORK_RESULT%==2350 (
    echo Требуется перезагрузка для завершения установки Framework.
    shutdown /r /t 5
    exit
) else (
    echo Ошибка установки Framework! Код: %FRAMEWORK_RESULT%
    pause
    exit /b 1
)

:: ===============================
:: Установка MSI
:: ===============================
:MSIInstall
echo ================================
echo Скачивание Локального модуля ЧЗ...
echo ================================
curl -L -o "%MSI_FILE%" "%MSI_URL%" --retry 3 --progress-bar
if errorlevel 1 (
    echo Ошибка скачивания ЧЗ!
    pause
    exit /b 1
)

echo ================================
echo Запуск установки "Локального модуля ЧЗ"...
echo ================================
msiexec /i "%MSI_FILE%" /qf /norestart
set MSI_CODE=%ERRORLEVEL%

echo Код установки MSI: %MSI_CODE%

if "%MSI_CODE%"=="0" (
    echo Установка завершена успешно.
    goto AfterMSI
)

if "%MSI_CODE%"=="3010" (
    echo MSI сообщил о необходимости перезагрузки, но продолжаем.
    goto AfterMSI
)

if "%MSI_CODE%"=="-2147021886" (
    echo MSI сообщил код 0x80070BC2 (нужна перезагрузка). Продолжаем.
    goto AfterMSI
)

echo Ошибка установки MSI! Код: %MSI_CODE%
pause
exit /b 1

:AfterMSI

:: ===============================
:: Включаем защиту
:: ===============================
netsh advfirewall set allprofiles state on >nul 2>&1
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1

echo Все операции завершены.

echo Закрытие через 10 секунд...
timeout /t 10 /nobreak >nul
exit
