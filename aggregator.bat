@echo off
chcp 1251 >nul
setlocal

:: =====================================
:: Настройки
:: =====================================
set "REPO_RAW=https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/scripts"
set "WORKDIR=%USERPROFILE%\Downloads\olservice"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

:: =====================================
:: Проверка администратора
:: =====================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
color 0A
echo OLService Utility
echo.
echo 1. RustDesk
echo 2. iikoCard
echo 3. Clean
echo 0. Выход
echo.
set /p choice=Выберите пункт: 

if "%choice%"=="1" set SCRIPT=rustdesk.bat
if "%choice%"=="2" set SCRIPT=iikocard.bat
if "%choice%"=="3" set SCRIPT=clean.bat
if "%choice%"=="0" goto END
if not defined SCRIPT goto MENU

set URL=%REPO_RAW%/%SCRIPT%
set LOCAL=%WORKDIR%\%SCRIPT%

echo [INFO] Скачивание %SCRIPT%...
curl -fsSL "%URL%" -o "%LOCAL%" 2>nul
if errorlevel 1 (
    echo [ERROR] Не удалось скачать %SCRIPT%!
    pause
    goto MENU
)

echo [INFO] Запуск %SCRIPT% от администратора в отдельном окне...
powershell -Command "Start-Process '%LOCAL%' -Verb RunAs"

echo [INFO] Скрипт запущен. Возврат в меню...
pause >nul
goto MENU

:END
echo.
pause
exit /b
