@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ===============================
:: НАСТРОЙКИ
:: ===============================
set CURRENT_VERSION=1.0
set REPO_RAW=https://raw.githubusercontent.com/poprugunchik/olservice_bat/main
set VERSION_URL=%REPO_RAW%/version.txt
set SELF_URL=%REPO_RAW%/aggregator.bat

set WORKDIR=%temp%\olservice
set LOG=%ProgramData%\OLService\aggregator.log

mkdir "%WORKDIR%" >nul 2>&1
mkdir "%ProgramData%\OLService" >nul 2>&1

:: ===============================
:: ЦВЕТ
:: ===============================
color 0B

:: ===============================
:: ЛОГ СТАРТА
:: ===============================
echo [%date% %time%] START >> "%LOG%"

:: ===============================
:: ПРОВЕРКА ОБНОВЛЕНИЯ
:: ===============================
curl -fsSL "%VERSION_URL%" -o "%WORKDIR%\version.txt" >nul 2>&1

if exist "%WORKDIR%\version.txt" (
    set /p REMOTE_VERSION=<"%WORKDIR%\version.txt"
    if not "%REMOTE_VERSION%"=="%CURRENT_VERSION%" (
        echo [%date% %time%] UPDATE %REMOTE_VERSION% >> "%LOG%"
        curl -fsSL "%SELF_URL%" -o "%~f0"
        echo Обновлено до версии %REMOTE_VERSION%
        timeout /t 2 >nul
        start "" "%~f0"
        exit /b
    )
)

:: ===============================
:: ПРОВЕРКА АДМИНА
:: ===============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Запуск с правами администратора...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ===============================
:: МЕНЮ
:: ===============================
:MENU
cls
echo ==========================================
echo        OLService Utility v%CURRENT_VERSION%
echo ==========================================
echo.
echo  [1] Установка / настройка RustDesk
echo  [2] Установка iikoCard
echo  [3] Очистка системы
echo.
echo  [0] Выход
echo.
set /p CHOICE=Выберите действие: 

if "%CHOICE%"=="1" set SCRIPT=rustdesk.bat
if "%CHOICE%"=="2" set SCRIPT=iikocard.bat
if "%CHOICE%"=="3" set SCRIPT=clean.bat
if "%CHOICE%"=="0" exit /b

if not defined SCRIPT (
    echo Неверный выбор
    timeout /t 2 >nul
    goto MENU
)

:: ===============================
:: СКАЧИВАНИЕ
:: ===============================
set SCRIPT_URL=%REPO_RAW%/scripts/%SCRIPT%
set LOCAL_SCRIPT=%WORKDIR%\%SCRIPT%

echo.
echo Загрузка %SCRIPT% ...
curl -fsSL "%SCRIPT_URL%" -o "%LOCAL_SCRIPT%"

if not exist "%LOCAL_SCRIPT%" (
    echo Ошибка загрузки файла
    pause
    goto MENU
)

:: ===============================
:: ЗАПУСК
:: ===============================
echo [%date% %time%] RUN %SCRIPT% >> "%LOG%"
call "%LOCAL_SCRIPT%"

echo.
echo Готово
pause
goto MENU
