@echo off
chcp 1251 >nul
title ЕГАИС / УТМ

:: Автоматический запуск от имени администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo ========================================
echo          ЕГАИС / УТМ
echo ========================================
echo.
echo 1 - Установка ЕГАИС
echo 2 - Обновление УТМ
echo 0 - Выход
echo.
set /p choice=Выберите действие:

if "%choice%"=="1" goto install
if "%choice%"=="2" goto update
if "%choice%"=="0" exit

goto menu

:: ========================================
:: УСТАНОВКА ЕГАИС
:: ========================================

:install

set "WORKDIR=%TEMP%\EGAIS_INSTALL"

set "RUTOKEN_URL=https://download.rutoken.ru/Rutoken/Drivers/Current/rtDrivers.exe"
set "UTM_URL=https://fsrar.gov.ru/opendata/dist/установщик_транспортного_модуля_версия_4.2.0_для_Windows.zip"

if exist "%WORKDIR%" rd /s /q "%WORKDIR%"
mkdir "%WORKDIR%"

echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-MpPreference -DisableRealtimeMonitoring $true"


echo.
echo ========================================
echo Скачивание драйвера Рутокен
echo ========================================

powershell -ExecutionPolicy Bypass -Command ^
"$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%RUTOKEN_URL%' -OutFile '%WORKDIR%\rtDrivers.exe'"

if not exist "%WORKDIR%\rtDrivers.exe" (
    echo Ошибка скачивания драйвера Рутокен.
    pause
    goto menu
)

echo.
echo ========================================
echo Установка драйвера Рутокен
echo ========================================

start /wait "" "%WORKDIR%\rtDrivers.exe"

echo.
echo ========================================
echo Скачивание УТМ
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%UTM_URL%' -OutFile '%WORKDIR%\utm.zip'"

if not exist "%WORKDIR%\utm.zip" (
    echo Ошибка скачивания УТМ.
    pause
    goto menu
)

echo.
echo ========================================
echo Распаковка УТМ
echo ========================================

powershell -ExecutionPolicy Bypass -Command ^
"Expand-Archive -Path '%WORKDIR%\utm.zip' -DestinationPath '%WORKDIR%\utm' -Force"

echo.
echo ========================================
echo Установка УТМ
echo ========================================

for /r "%WORKDIR%\utm" %%F in (*.exe) do (
    echo Запуск %%~nxF
    start /wait "" "%%F"
    goto open_port
)

echo Установщик УТМ не найден.
echo Включаем Windows Firewall...
netsh advfirewall set allprofiles state on

echo Включаем защиту в реальном времени Windows Defender...
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false"
pause
goto menu

:: ========================================
:: ОБНОВЛЕНИЕ УТМ
:: ========================================

:update

set "WORKDIR=%TEMP%\UTM_UPDATE"
set "UTM_URL=https://fsrar.gov.ru/opendata/dist/установщик_транспортного_модуля_версия_4.2.0_для_Windows.zip"

if exist "%WORKDIR%" rd /s /q "%WORKDIR%"
mkdir "%WORKDIR%"

echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-MpPreference -DisableRealtimeMonitoring $true"


echo.
echo ========================================
echo Удаление текущего УТМ
echo ========================================

if exist "C:\UTM\unins000.exe" (
    start /wait "" "C:\UTM\unins000.exe"
) else (
    echo УТМ не найден, пропускаем удаление.
)

echo.
echo ========================================
echo Скачивание новой версии
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%UTM_URL%' -OutFile '%WORKDIR%\utm.zip'"

if not exist "%WORKDIR%\utm.zip" (
    echo Ошибка скачивания УТМ.
    pause
    goto menu
)

echo.
echo ========================================
echo Распаковка
echo ========================================

powershell -ExecutionPolicy Bypass -Command ^
"Expand-Archive -Path '%WORKDIR%\utm.zip' -DestinationPath '%WORKDIR%\utm' -Force"

echo.
echo ========================================
echo Установка УТМ
echo ========================================

for /r "%WORKDIR%\utm" %%F in (*.exe) do (
    echo Запуск %%~nxF
    start /wait "" "%%F"
    goto open_port
)

echo Установщик УТМ не найден.
echo Включаем Windows Firewall...
netsh advfirewall set allprofiles state on

echo Включаем защиту в реальном времени Windows Defender...
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false"
pause
goto menu

:: ========================================
:: ОТКРЫТИЕ ПОРТА
:: ========================================

:open_port

echo.
echo ========================================
echo Открытие порта 8080
echo ========================================

netsh advfirewall firewall delete rule name="Open Port 8080" >nul 2>&1
netsh advfirewall firewall add rule name="Open Port 8080" dir=in action=allow protocol=TCP localport=8080

echo.
echo ========================================
echo Операция завершена
echo ========================================

pause
goto menu