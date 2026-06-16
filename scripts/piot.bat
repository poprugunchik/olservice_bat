@echo off
chcp 1251 >nul
setlocal
setlocal EnableExtensions EnableDelayedExpansion

:: Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Требуются права администратора...
    
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process '%~f0' -Verb RunAs"

    exit /b
)


set "WORKDIR=C:\Temp\LMInstall"
set "LOGFILE=%WORKDIR%\main.log"


if not exist "%WORKDIR%" mkdir "%WORKDIR%" 2>nul

REM Очистка перед стартом
echo ===============================================> "%LOGFILE%"
echo START %DATE% %TIME%>> "%LOGFILE%"
echo ===============================================>> "%LOGFILE%"
echo.>> "%LOGFILE%"

call :LOG "=== Скрипт запущен ==="

call :RUN
exit /b

:LOG
REM Единая функция логирования с временем
>>"%LOGFILE%" echo [%DATE% %TIME%] %*
exit /b

:RUN
call :LOG "=== НАЧАЛО РАБОТЫ ==="

set "WORKDIR=C:\Temp\LMInstall"
set "LIST=%WORKDIR%\install_list.txt"
set "FRAMEWORK_URL=https://go.microsoft.com/fwlink/?LinkId=2088631"
set "FRAMEWORK_FILE=%TEMP%\ndp48-x86-x64-allos-enu.exe"
set "FTP_URL=ftp://rustdesk.olservice.ru/files/ndp48-x86-x64-allos-enu.exe"
set "FTP=ftp://rustdesk.olservice.ru/files"
set "USER=olservice"
set "PASS=Пампам123"

if not exist "%WORKDIR%" mkdir "%WORKDIR%" 2>nul

echo.
echo ========================================
echo            ПИОТ ГОСПОДИ
echo ========================================
echo.
echo 1 - Первичная установка
echo 2 - Настройка ПИОТ
echo 3 - Проверка статуса ПИОТ
echo 0 - Выход
echo.

choice /c 1230 /m "Выберите режим"

if errorlevel 4 goto :EXIT
if errorlevel 3 goto :STATUS
if errorlevel 2 goto :PIOT_SETUP
if errorlevel 1 goto :FIRST_INSTALL

:: =======================================
:: FIRST INSTALL
:: =======================================
:FIRST_INSTALL
call :LOG "=== Режим: ПЕРВИЧНАЯ УСТАНОВКА ==="
echo.
echo Выбран режим: Первичная установка
echo ========================================

set "TOKEN_FILE=%WORKDIR%\token.txt"

if not exist "C:\Temp\LMInstall" mkdir "C:\Temp\LMInstall" 2>nul

rem --- читаем токен ---
set "TOKEN="
for /f "delims=" %%A in ('type "%TOKEN_FILE%" 2^>nul') do set "TOKEN=%%A"

echo.
echo ==============================
echo TOKEN MANAGER
echo ==============================
echo.

if defined TOKEN (
    echo Текущий токен:
    echo [%TOKEN%]
    call :LOG "Текущий токен: %TOKEN%"
) else (
    echo Токен не найден.
    call :LOG "Токен не найден"
    goto :change
)

echo.
echo [1] Оставить
echo [2] Заменить
echo.

choice /c 12 /m "Выберите режим"
if errorlevel 2 goto :change
if errorlevel 1 goto :end


:change
echo.
set /p TOKEN=Введите новый токен:
call :LOG "Введен новый токен: %TOKEN%"

powershell -NoProfile -Command "[System.IO.File]::WriteAllText('%TOKEN_FILE%', '%TOKEN%')"
call :LOG "Токен сохранен в файл: %TOKEN_FILE%"

echo.
echo Токен обновлен, вы молодец.
goto :end

:end
echo.
timeout /t 3 >nul
echo.

call :LOG "Отключаем Windows Firewall..."
netsh advfirewall set allprofiles state off >nul 2>&1
call :LOG "Windows Firewall отключен"

call :LOG "Отключаем Defender..."
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1
call :LOG "Defender отключен"

echo.
echo ========================================
echo CHECK SYSTEM STATE
echo ========================================

if exist "%LIST%" del "%LIST%" 2>nul

call :LOG "Проверка установленных компонентов..."

powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=@('ESM|Единый Сервисный Модуль|1.6.2.1','KKT|Драйвер ККТ v.10 (32-bit)|10.10.8.24','LM|Локальный модуль Честный Знак|2.5.1','CONTROLLER|ЕСП Контроллер ЛМ ЧЗ|1.6.2.1'); $reg=Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue; $need=@(); foreach($i in $list){$key,$name,$ver=$i -split '\|'; $found=$reg | Where-Object { $_.DisplayName -and $_.DisplayName -like ('*'+$name+'*') } | Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue | Select-Object -First 1; if(-not $found){Write-Host '[NOT INSTALLED]' $key; $need+=$key} elseif([version]$found -ne [version]$ver){Write-Host '[VERSION MISMATCH]' $key '->' $found 'required:' $ver; $need+=$key} else {Write-Host '[OK]' $key '->' $found}}; $need | Set-Content '%LIST%' -Encoding ASCII"

echo.
echo NEED INSTALL LIST
echo ----------------------------------------

if exist "%LIST%" (
    type "%LIST%"
    call :LOG "Список для установки:"
    for /f "delims=" %%A in ('type "%LIST%"') do call :LOG "  - %%A"
) else (
    echo Nothing to install
    call :LOG "Все компоненты уже установлены"
)

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
    call :LOG ".NET 4.8 уже установлен"
) else (
    echo Installing .NET 4.8...
    call :LOG "Начинаем установку .NET 4.8..."

    :: 1. FTP (основной)
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP_URL%','%FRAMEWORK_FILE%') } catch { }"

    :: 2. Microsoft (fallback + FIX TLS)
    if not exist "%FRAMEWORK_FILE%" (
        call :LOG "FTP не сработал, пробуем Microsoft..."

        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%FRAMEWORK_URL%' -OutFile '%FRAMEWORK_FILE%' -ErrorAction Stop } catch { }"
    )

    :: 3. финальная проверка
    if not exist "%FRAMEWORK_FILE%" (
        call :LOG "ОШИБКА: Не удалось скачать .NET 4.8 ни с Microsoft, ни с FTP"
        goto :CLEANUP
    )

    call :LOG "Файл .NET скачан: %FRAMEWORK_FILE%"

    :: 4. установка
    start /wait "" "%FRAMEWORK_FILE%" /quiet /norestart
    call :LOG "Установка .NET 4.8 завершена с кодом: %errorlevel%"

    if errorlevel 1 (
        call :LOG "ОШИБКА: Установка .NET 4.8 не удалась"
        goto :CLEANUP
    )
)
echo.
echo ========================================
echo DOWNLOAD PHASE
echo ========================================

for /f "delims=" %%A in (%LIST%) do (
    echo ----------------------------------------
    echo Download: %%A
    echo ----------------------------------------
    call :LOG "Скачивание компонента: %%A"

    if "%%A"=="ESM" (
        call :LOG "Скачивание ESM main package..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/esm_1.6.2.1-windows-signed-setup.exe','%WORKDIR%\esm_1.6.2.1-windows-signed-setup.exe')"
        
        call :LOG "Скачивание ESM helper..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/esm_install.exe','%WORKDIR%\esm_install.exe')"
        call :LOG "ESM компоненты скачаны"
    )

    if "%%A"=="LM" (
        call :LOG "Скачивание LM..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/regime-2.5.1-2.msi','%WORKDIR%\regime-2.5.1-2.msi')"
        
        call :LOG "Скачивание reg_install..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/reg_install.exe','%WORKDIR%\reg_install.exe')"
        call :LOG "LM компоненты скачаны"
	
    )

    if "%%A"=="KKT" (
        call :LOG "Скачивание KKT..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/KKT10-10.10.8.24-windows32-setup-signed.exe','%WORKDIR%\KKT10-10.10.8.24-windows32-setup-signed.exe')"
        
        call :LOG "Скачивание dto_install..."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/dto_install.exe','%WORKDIR%\dto_install.exe')"
        call :LOG "KKT компоненты скачаны"
    )
)

echo.
echo ========================================
echo DOWNLOAD INSTALLER
echo ========================================
call :LOG "Скачивание installer.bat..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/installer.bat','%WORKDIR%\installer.bat')"
call :LOG "installer.bat скачан"

echo.
echo ========================================
echo START INSTALLER
echo ========================================
pushd "%WORKDIR%"
call :LOG "Запуск installer.bat из папки %WORKDIR%"
call "%WORKDIR%\installer.bat"

echo ERRORLEVEL=%ERRORLEVEL%

call :LOG "installer.bat завершил работу"
popd

echo.
echo ========================================
echo DOWNLOAD INIT BAT
echo ========================================
call :LOG "Скачивание init.bat..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/init.bat','%WORKDIR%\init.bat')"
call :LOG "init.bat скачан"

start "" cmd /c "%WORKDIR%\init.bat"
call :LOG "Запущен init.bat"

goto CLEANUP

:CLEANUP
call :LOG "=== ЗАВЕРШЕНИЕ УСТАНОВКИ ==="
call :LOG "Включаем Windows Firewall..."
netsh advfirewall set allprofiles state on >nul 2>&1
call :LOG "Windows Firewall включен"

call :LOG "Включаем Defender..."
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1
call :LOG "Defender включен"

echo.
echo Установка завершена.
timeout /t 10 >nul
goto EXIT

:: =======================================
:: PIOT
:: =======================================
:PIOT_SETUP
call :LOG "=== Режим: НАСТРОЙКА ПИОТ ==="
echo Настройка ПИОТ
echo.
echo ========================================
echo            Выбор версии
echo ========================================
echo.
echo 1 - Версия 9.2
echo 2 - Версия 9.4
echo 0 - Выход
echo.

choice /c 120 /m "Выберите режим"

if errorlevel 3 goto EXIT
if errorlevel 2 goto NEW_VERSION
if errorlevel 1 goto OLD_VERSION

:OLD_VERSION
call :LOG "=== Установка ПИОТ версии 9.2 ==="
echo.
echo ========================================
echo ADD CERITIFICATES
echo ========================================
echo Установка сертификатов...
call :LOG "Отключаем Windows Firewall..."
netsh advfirewall set allprofiles state off >nul 2>&1
call :LOG "Отключаем Defender..."
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1


call :LOG "Установка сертификатов в доверенные корневые центры..."

certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\ca.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt_base.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\esp.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\server.crt" >nul 2>&1

call :LOG "Сертификаты установлены"
echo.
echo Сертификаты установлены.

:: =======================================
:: PIOT INSTALL FLOW
:: =======================================
echo.
echo ========================================
echo DOWNLOADING ZIP
echo ========================================
call :LOG "Скачивание плагина ПИОТ 9.2..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip','%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip')"
call :LOG "Плагин скачан"

set "PLUGINS_DIR=C:\Program Files\iiko\iikoRMS\Front.Net\Plugins"
set "FRONT_DIR=C:\Program Files\iiko\iikoRMS\Front.Net"
set "ZIP_FILE=%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip"
set "DESKTOP=%USERPROFILE%\Desktop"

echo ========================================
echo STOP IIKO FRONT
echo ========================================
call :LOG "Остановка iikoFront.Net.exe..."
taskkill /f /im iikoFront.Net.exe /T >nul 2>&1
call :LOG "iikoFront.Net.exe остановлен"

echo.
echo ========================================
echo BACKUP OLD PLUGIN
echo ========================================

set "FOUND=0"

for /d %%D in ("%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin*") do (
    set "FOUND=1"
    echo Moving %%D to Desktop
    call :LOG "Перемещение старой версии плагина: %%D -> %DESKTOP%"
    move "%%D" "%DESKTOP%" >nul 2>&1
)

if "!FOUND!"=="0" (
    echo No old plugin found, skipping backup
    call :LOG "Старая версия плагина не найдена"
)

echo.
echo ========================================
echo COPY ZIP
echo ========================================
copy /y "%ZIP_FILE%" "%PLUGINS_DIR%" >nul
call :LOG "ZIP-файл скопирован в %PLUGINS_DIR%"

echo.
echo ========================================
echo EXTRACT ZIP
echo ========================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip' '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280'"
call :LOG "ZIP-файл распакован"

echo.
echo ========================================
echo START IIKO FRONT
echo ========================================
start "" "%FRONT_DIR%\iikoFront.Net.exe"
call :LOG "Запущен iikoFront.Net.exe"

echo Waiting for config.json...
call :LOG "Ожидание создания config.json..."

set "CONFIG_FILE=%APPDATA%\iiko\CashServer\PluginConfigs\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280\config.json"

call :wait_for_file "%CONFIG_FILE%" 300

if errorlevel 1 (
    call :LOG "ОШИБКА: config.json не создан за отведенное время"
    echo ERROR: config.json not created in time
    exit /b 1
)

call :LOG "config.json обнаружен"
echo Config detected!
echo DONE
goto CLEANUP_PIOT

:NEW_VERSION
call :LOG "=== Установка ПИОТ версии 9.4 ==="
echo.
echo ========================================
echo ADD CERITIFICATES
echo ========================================
echo Установка сертификатов...
call :LOG "Отключаем Windows Firewall..."
netsh advfirewall set allprofiles state off >nul 2>&1
call :LOG "Отключаем Defender..."
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1


call :LOG "Установка сертификатов в доверенные корневые центры..."

certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\ca.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt_base.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\esp.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt.crt" >nul 2>&1
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\server.crt" >nul 2>&1

call :LOG "Сертификаты установлены"
echo.
echo Сертификаты установлены.

:: =======================================
:: PIOT INSTALL FLOW
:: =======================================
echo.
echo ========================================
echo DOWNLOADING ZIP
echo ========================================
call :LOG "Скачивание плагина ПИОТ 9.4..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip','%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip')"
call :LOG "Плагин скачан"

set "PLUGINS_DIR=C:\Program Files\iiko\iikoRMS\Front.Net\Plugins"
set "FRONT_DIR=C:\Program Files\iiko\iikoRMS\Front.Net"
set "ZIP_FILE=%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip"
set "DESKTOP=%USERPROFILE%\Desktop"

echo ========================================
echo STOP IIKO FRONT
echo ========================================
call :LOG "Остановка iikoFront.Net.exe..."
taskkill /f /im iikoFront.Net.exe /T >nul 2>&1
call :LOG "iikoFront.Net.exe остановлен"

echo.
echo ========================================
echo BACKUP OLD PLUGIN
echo ========================================

set "FOUND=0"

for /d %%D in ("%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin*") do (
    set "FOUND=1"
    echo Moving %%D to Desktop
    call :LOG "Перемещение старой версии плагина: %%D -> %DESKTOP%"
    move "%%D" "%DESKTOP%" >nul 2>&1
)

if "!FOUND!"=="0" (
    echo No old plugin found, skipping backup
    call :LOG "Старая версия плагина не найдена"
)

echo.
echo ========================================
echo COPY ZIP
echo ========================================
copy /y "%ZIP_FILE%" "%PLUGINS_DIR%" >nul
call :LOG "ZIP-файл скопирован в %PLUGINS_DIR%"

echo.
echo ========================================
echo EXTRACT ZIP
echo ========================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip' '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281'"
call :LOG "ZIP-файл распакован"

echo.
echo ========================================
echo START IIKO FRONT
echo ========================================
start "" "%FRONT_DIR%\iikoFront.Net.exe"
call :LOG "Запущен iikoFront.Net.exe"

echo Waiting for config.json...
call :LOG "Ожидание создания config.json..."

set "CONFIG_FILE=%APPDATA%\iiko\CashServer\PluginConfigs\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281\config.json"

call :wait_for_file "%CONFIG_FILE%" 300

if errorlevel 1 (
    call :LOG "ОШИБКА: config.json не создан за отведенное время"
    echo ERROR: config.json not created in time
    exit /b 1
)

call :LOG "config.json обнаружен"
echo Config detected!
echo DONE
goto CLEANUP_PIOT

:CLEANUP_PIOT
call :LOG "Восстановление настроек защиты..."
netsh advfirewall set allprofiles state on >nul 2>&1
call :LOG "Windows Firewall включен"
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1
call :LOG "Defender включен"
goto EXIT

:wait_for_file
set "FILE=%~1"
set "TIMEOUT=%~2"
set /a elapsed=0

:wait_loop
if exist "%FILE%" exit /b 0

timeout /t 2 /nobreak >nul
set /a elapsed+=2

if %elapsed% geq %TIMEOUT% exit /b 1
goto wait_loop

:STATUS
call :LOG "=== Режим: ПРОВЕРКА СТАТУСА ==="

set "WORKDIR=C:\Temp\LMInstall"
set "TOKEN_FILE=%WORKDIR%\token.txt"

call :GET_TOKEN

set HOST=127.0.0.1
set PORT=5995
set LOGIN=admin
set PASSWORD=admin

echo.
echo =========================
echo СТАТУС
echo =========================

call :LOG "Запрос статуса от %HOST%:%PORT%"

powershell -NoProfile -ExecutionPolicy Bypass "& {$pair='%LOGIN%:%PASSWORD%';$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair));$headers=@{Authorization='Basic '+$auth};try{Invoke-RestMethod -Uri 'http://%HOST%:%PORT%/api/v2/status' -Method Get -Headers $headers | ConvertTo-Json -Depth 10}catch{Write-Host 'Ошибка:';Write-Host $_.Exception.Message}}"

timeout /t 10 >nul
goto EXIT

:GET_TOKEN

if errorlevel 1 (
    call :LOG "Статус отменен: токен не введен"
    goto EXIT
)

if not exist "%WORKDIR%" mkdir "%WORKDIR%" 2>nul

set "TOKEN="

for /f "delims=" %%A in ('type "%TOKEN_FILE%" 2^>nul') do (
    set "TOKEN=%%A"
)

if defined TOKEN (
    call :LOG "Токен найден"
    exit /b 0
)

echo.
echo ==============================
echo TOKEN MANAGER
echo ==============================
echo.

echo Токен не найден.
echo.

set /p TOKEN=Введите токен:

if not defined TOKEN (
    echo Токен не введен.
    exit /b 1
)

powershell -NoProfile -Command "[System.IO.File]::WriteAllText('%TOKEN_FILE%', '%TOKEN%')"

call :LOG "Создан новый токен"
call :LOG "Токен сохранен в %TOKEN_FILE%"

exit /b 0

:: =======================================
:: EXIT
:: =======================================
:EXIT
call :LOG "=== СКРИПТ ЗАВЕРШЕН ==="
echo.
echo Выход...
timeout /t 2 >nul
exit /b