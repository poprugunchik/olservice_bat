@echo off
chcp 1251 >nul
title Полная очистка мусора
color 0A

setlocal enableextensions
set "USERPROFILE_PATH=C:\Users\%USERNAME%"

:: Устанавливаем путь для лог-файла
set LOG_FILE="%USERPROFILE%\Desktop\cleanup-log.txt"

:: Создаем или очищаем файл лога
echo Очистка началась %date% %time% > %LOG_FILE%

echo ==================================================
echo         ПОЛНАЯ ОЧИСТКА СИСТЕМЫ (CP1251)
echo ==================================================
echo Очистка началась %date% %time% >> %LOG_FILE%

echo Очистка временных файлов пользователя...
echo Очистка временных файлов пользователя... >> %LOG_FILE%

:: Удаляем файлы в корне %TEMP%, кроме батника
for %%F in ("%temp%\*") do (
    if /I not "%%~nxF"=="clean.bat" (
        if exist "%%F" (
            if not "%%~nxF"=="olservice" if not "%%~nxF"=="olservice_debug" (
                del /f /q "%%F" >> %LOG_FILE% 2>&1 2>nul
            )
        )
    )
)

:: Удаляем папки в корне %TEMP%, кроме olservice и olservice_debug
for /d %%D in ("%temp%\*") do (
    if /I not "%%~nxD"=="olservice" if not "%%~nxD"=="olservice_debug" (
        rd /s /q "%%D" >> %LOG_FILE% 2>&1 2>nul
    )
)

echo Очистка временных файлов Windows...
echo Очистка временных файлов Windows... >> %LOG_FILE%
if exist "C:\Windows\Temp" (
    del /s /q "C:\Windows\Temp\*.*" >> %LOG_FILE% 2>&1
    for /d %%x in ("C:\Windows\Temp\*") do rd /s /q "%%x" >> %LOG_FILE% 2>&1
) else (
    echo Папка C:\Windows\Temp не найдена >> %LOG_FILE%
)

:: Очистка логов
echo Очистка логов Windows...
echo Очистка логов Windows... >> %LOG_FILE%
for %%L in ("C:\Windows\Logs" "C:\Windows\System32\LogFiles") do (
    if exist %%L (
        del /s /q "%%L\*.*" >> %LOG_FILE% 2>&1
        for /d %%x in ("%%L\*") do rd /s /q "%%x" >> %LOG_FILE% 2>&1
    ) else (
        echo Папка %%L не найдена >> %LOG_FILE%
    )
)

:: Очистка Diagnosis
echo Очистка папки Diagnosis...
echo Очистка папки Diagnosis... >> %LOG_FILE%
if exist "C:\ProgramData\Microsoft\Diagnosis" (
    del /s /q "C:\ProgramData\Microsoft\Diagnosis\*.*" >> %LOG_FILE% 2>&1
    for /d %%x in ("C:\ProgramData\Microsoft\Diagnosis\*") do rd /s /q "%%x" >> %LOG_FILE% 2>&1
) else (
    echo Папка Diagnosis не найдена >> %LOG_FILE%
)

:: Очистка кэша браузеров
echo Очистка кэша Chrome...
echo Очистка кэша Chrome... >> %LOG_FILE%
del /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*.*" >> %LOG_FILE% 2>&1
del /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache\*.*" >> %LOG_FILE% 2>&1

echo Очистка кэша Edge...
echo Очистка кэша Edge... >> %LOG_FILE%
del /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache\*.*" >> %LOG_FILE% 2>&1
del /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Code Cache\*.*" >> %LOG_FILE% 2>&1

echo Очистка кэша Firefox...
echo Очистка кэша Firefox... >> %LOG_FILE%
del /s /q "%APPDATA%\Mozilla\Firefox\Profiles\*.default-release\cache2\entries\*.*" >> %LOG_FILE% 2>&1
del /s /q "%APPDATA%\Mozilla\Firefox\Profiles\*.default-release\cache2\doomed\*.*" >> %LOG_FILE% 2>&1


echo ===============================
echo   Очистка логов iiko (старше 5 дней)...
echo ===============================

PowerShell.exe -NoProfile -Command "Get-ChildItem -Path \"$env:USERPROFILE\AppData\Roaming\iiko\CashServer\Logs\" | Where-Object { $_.PSIsContainer -eq $false -and $_.LastWriteTime -lt (Get-Date).AddDays(-5) } | Remove-Item -Force"



:: Очистка корзины
echo Очистка корзины...
echo Очистка корзины... >> %LOG_FILE%
PowerShell.exe -NoProfile -Command "Clear-RecycleBin -Force" >> %LOG_FILE% 2>&1

echo.
echo ===============================================
echo Очистка завершена.
echo ===============================================
echo Лог работы записан в файл: %LOG_FILE%
echo ===============================================

