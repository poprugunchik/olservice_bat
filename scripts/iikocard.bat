@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion

echo ============================================
echo      Выберите действие:
echo.
echo   1 - Обновить с удалением
echo   2 - Удалить базу и перезапустить службу
echo ============================================
echo.
set /p choice="Введите 1 или 2 и нажмите Enter: "

if "%choice%"=="2" goto REMOVE_AND_RESTART
if "%choice%"=="1" goto UPDATE_AND_INSTALL

echo Неверный выбор. Завершение работы.
timeout /t 5 >nul
exit /b


:REMOVE_AND_RESTART
echo.
echo ============================================
echo УДАЛЕНИЕ БАЗЫ И ПЕРЕЗАПУСК СЛУЖБЫ
echo ============================================
echo.

echo Остановка службы iikoCard5POS...
net stop iikoCard5POS
timeout /t 10 /nobreak

echo Удаление базы данных...
rmdir /s /q "C:\Users\iikoCard5POS\AppData\Roaming\iiko" 2>nul
rmdir /s /q "C:\Windows\ServiceProfiles\iikoCard5POS\AppData\Roaming\iiko" 2>nul

echo Запуск службы iikoCard5POS...
net start iikoCard5POS
if %errorlevel%==0 (
    echo Служба успешно запущена.
) else (
    echo Не удалось запустить службу. Проверьте вручную.
)
timeout /t 10
exit /b


:UPDATE_AND_INSTALL
echo.
echo ============================================
echo ОБНОВЛЕНИЕ С УДАЛЕНИЕМ
echo ============================================
echo.

set "DOWNLOAD_URL=https://m1.iiko.cards/ru-RU/About/DownloadPosInstaller?useRc=False"
set "INSTALLER_PATH=C:\Users\%USERNAME%\Downloads\Setup.iikoCard5.POS.exe"

echo Остановка службы iikoCard5POS...
net stop iikoCard5POS
timeout /t 15 /nobreak

sc query iikoCard5POS | find "STOPPED" >nul
if not %errorlevel%==0 (
    echo Не удалось корректно остановить службу. Принудительное завершение процесса...
    taskkill /IM iikoCard5POS.exe /F >nul 2>nul
)

echo Удаление старых данных iikoCard5...
rmdir /s /q "C:\Users\iikoCard5POS\AppData\Roaming\iiko\iikoCard5"
rmdir /s /q "C:\Windows\ServiceProfiles\iikoCard5POS\AppData\Roaming\iiko\iikoCard5"

if exist "%INSTALLER_PATH%" (
    echo Старый установщик найден — удаляю...
    del /f /q "%INSTALLER_PATH%"
)

echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off

echo Отключаем Защиту в реальном времени Windows Defender...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-MpPreference -DisableRealtimeMonitoring $true"

:: Определяем, какой curl.exe использовать
set "CURL_EXE="

if exist "%SystemRoot%\System32\curl.exe" (
    set "CURL_EXE=%SystemRoot%\System32\curl.exe"
) else if exist "C:\iiko\curl\curl-8.6.0_3-win64-mingw\bin\curl.exe" (
    set "CURL_EXE=C:\iiko\curl\curl-8.6.0_3-win64-mingw\bin\curl.exe"
) else (
    echo curl.exe не найден. Установите curl.
    pause
    exit /b 1
)

echo Используется curl:
"%CURL_EXE%" --version
echo.

echo Скачивание установщика iikoCardPOS...
"%CURL_EXE%" -L -o "%INSTALLER_PATH%" "%DOWNLOAD_URL%"
if not exist "%INSTALLER_PATH%" (
    echo Ошибка: не удалось скачать файл. Проверьте интернет-соединение.
    exit /b
)
echo Установщик успешно скачан: %INSTALLER_PATH%

echo Запуск установки iikoCardPOS...
powershell -Command Start-Process '%INSTALLER_PATH%' -ArgumentList '/S' -Verb RunAs

echo Ожидание завершения установки...
set "install_wait_time=0"
:INSTALL_WAIT
timeout /t 30 /nobreak
set /a install_wait_time+=30

if exist "C:\Windows\ServiceProfiles\iikoCard5POS\AppData\Roaming\iiko\iikoCard5" (
    dir "C:\Windows\ServiceProfiles\iikoCard5POS\AppData\Roaming\iiko\iikoCard5" >nul 2>nul
    if %errorlevel%==0 (
        echo Установка завершена успешно.
        goto INSTALL_DONE
    )
)

if exist "C:\Users\iikoCard5POS\AppData\Roaming\iiko\iikoCard5" (
    dir "C:\Users\iikoCard5POS\AppData\Roaming\iiko\iikoCard5" >nul 2>nul
    if %errorlevel%==0 (
        echo Установка завершена успешно.
        goto INSTALL_DONE
    )
)

if %install_wait_time% GEQ 1200 (
    echo Ошибка: установка не завершилась за 20 минут. Завершение работы.
    exit /b
)
goto INSTALL_WAIT

:INSTALL_DONE
echo Установка завершена успешно.

echo Включаем Windows Firewall...
netsh advfirewall set allprofiles state on

echo Включаем защиту в реальном времени Windows Defender...
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false"

timeout /t 20 /nobreak
exit /b