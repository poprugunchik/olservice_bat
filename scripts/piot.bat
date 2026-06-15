@echo off
chcp 1251 >nul
setlocal
setlocal EnableExtensions EnableDelayedExpansion

set "WORKDIR=C:\Temp\LMInstall"
set "LIST=%WORKDIR%\install_list.txt"
set "FRAMEWORK_URL=https://go.microsoft.com/fwlink/?LinkId=2088631"
set "FRAMEWORK_FILE=%TEMP%\ndp48-x86-x64-allos-enu.exe"
set "FTP=ftp://rustdesk.olservice.ru/files"
set "USER=olservice"
set "PASS=Пампам123"


if not exist "%WORKDIR%" mkdir "%WORKDIR%"

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

echo.
echo Выбран режим: Первичная установка
echo ========================================

echo.
echo ========================================
echo TOKEN CHECK
echo ========================================

if not defined TOKEN (
    echo Токен не найден.
    set /p "TOKEN=Введите токен: "

    >"%WORKDIR%\token.txt" (
        <nul set /p "=!TOKEN!"
    )
) else (
    echo Найден токен: !TOKEN!
)

timeout /t 3 >nul
echo.

echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1


echo.
echo ========================================
echo CHECK SYSTEM STATE
echo ========================================

if exist "%LIST%" del "%LIST%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=@('ESM|Единый Сервисный Модуль|1.6.2.1','CONTROLLER|ЕСП Контроллер ЛМ ЧЗ|1.6.2.1','LM|Локальный модуль Честный Знак|2.5.1','KKT|Драйвер ККТ v.10 (32-bit)|10.10.8.24'); $reg=Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue; $need=@(); foreach($i in $list){$key,$name,$ver=$i -split '\|'; $found=$reg | Where-Object { $_.DisplayName -and $_.DisplayName -like ('*'+$name+'*') } | Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue | Select-Object -First 1; if(-not $found){Write-Host '[NOT INSTALLED]' $key; $need+=$key} elseif([version]$found -ne [version]$ver){Write-Host '[VERSION MISMATCH]' $key '->' $found 'required:' $ver; $need+=$key} else {Write-Host '[OK]' $key '->' $found}}; $need | Set-Content '%LIST%' -Encoding ASCII"

echo.
echo NEED INSTALL LIST
echo ----------------------------------------

if exist "%LIST%" (
    type "%LIST%"
) else (
    echo Nothing to install
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
) else (
    echo Installing .NET 4.8...

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Invoke-WebRequest -Uri '%FRAMEWORK_URL%' -OutFile '%FRAMEWORK_FILE%'"

    if not exist "%FRAMEWORK_FILE%" goto :CLEANUP

    start /wait "" "%FRAMEWORK_FILE%" /quiet /norestart

    if errorlevel 1 goto :CLEANUP
)


echo.
echo ========================================
echo DOWNLOAD PHASE
echo ========================================

set "FTP=ftp://rustdesk.olservice.ru/files"
set "USER=olservice"
set "PASS=Пампам123"

for /f "delims=" %%A in (%LIST%) do (

    echo ----------------------------------------
    echo Download: %%A
    echo ----------------------------------------

    if "%%A"=="ESM" (

    echo Download ESM main package...

    powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/esm_1.6.2.1-windows-signed-setup.exe','%WORKDIR%\esm_1.6.2.1-windows-signed-setup.exe')"

    echo Download ESM helper...

    powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/esm_install.exe','%WORKDIR%\esm_install.exe')"
	)

    if "%%A"=="LM" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/regime-2.5.1-2.msi','%WORKDIR%\regime-2.5.1-2.msi')"
    
	echo Download LM...
	
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/reg_install.exe','%WORKDIR%\reg_install.exe')"
	)

    if "%%A"=="KKT" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/KKT10-10.10.8.24-windows32-setup-signed.exe','%WORKDIR%\KKT10-10.10.8.24-windows32-setup-signed.exe')"
    
	echo Download DTO...
	
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('%FTP%/dto_install.exe','%WORKDIR%\dto_install.exe')"
	)
)

echo.
echo ========================================
echo DOWNLOAD INSTALLER
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/installer.bat','%WORKDIR%\installer.bat')"

echo.
echo ========================================
echo START INSTALLER
echo ========================================

pushd "%WORKDIR%"
start /wait installer.bat
popd

echo.
echo ========================================
echo DOWNLOAD INIT BAT
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/init.bat','%WORKDIR%\init.bat')"

start "" /min cmd /c "%WORKDIR%\init.bat"

goto CLEANUP

:CLEANUP
netsh advfirewall set allprofiles state on >nul 2>&1
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1


echo.
echo Установка завершена.
timeout /t 10 >nul
goto EXIT


:: =======================================
:: PIOT
:: =======================================
:PIOT_SETUP
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
echo.
echo ========================================
echo ADD CERITIFICATES
echo ========================================
echo Установка сертификатов...
echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1

REM Корневые сертификаты
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\ca.crt"
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt_base.crt"

REM Доверенные лица
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\esp.crt"
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\gismt.crt"
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\server.crt"

echo.
echo Сертификаты установлены.

:: =======================================
:: PIOT INSTALL FLOW
:: =======================================
echo.
echo ========================================
echo DOWNLOADING ZIP
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip','%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip')"



set "PLUGINS_DIR=C:\Program Files\iiko\iikoRMS\Front.Net\Plugins"
set "FRONT_DIR=C:\Program Files\iiko\iikoRMS\Front.Net"
set "ZIP_FILE=%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip"
set "DESKTOP=%USERPROFILE%\Desktop"

echo ========================================
echo STOP IIKO FRONT
echo ========================================
taskkill /f /im iikoFront.Net.exe /T >nul 2>&1

echo.
echo ========================================
echo BACKUP OLD PLUGIN
echo ========================================

set "FOUND=0"

for /d %%D in ("%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin*") do (
    set "FOUND=1"
    echo Moving %%D to Desktop
    move "%%D" "%DESKTOP%" >nul 2>&1
)

if "!FOUND!"=="0" (
    echo No old plugin found, skipping backup
)


echo.
echo ========================================
echo COPY ZIP
echo ========================================

copy /y "%ZIP_FILE%" "%PLUGINS_DIR%" >nul

echo.
echo ========================================
echo EXTRACT ZIP
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280.zip' '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280'"

echo.
echo ========================================
echo START IIKO FRONT
echo ========================================

start "" "%FRONT_DIR%\iikoFront.Net.exe"

echo Waiting for config.json...

set "CONFIG_FILE=C:\Users\admin\AppData\Roaming\iiko\CashServer\PluginConfigs\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview4.1.0.280\config.json"

call :wait_for_file "%CONFIG_FILE%" 300

if errorlevel 1 (
    echo ERROR: config.json not created in time
    exit /b 1
)

echo Config detected!

echo DONE
goto CLEANUP

:NEW_VERSION
echo.
echo ========================================
echo ADD CERITIFICATES
echo ========================================
echo Установка сертификатов...
echo Отключаем Windows Firewall...
netsh advfirewall set allprofiles state off >nul 2>&1

echo Отключаем Defender...
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1

REM Корневые сертификаты
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\ca.crt"
certutil -addstore "Root" "C:\ProgramData\ESP\ESM\um\gismt_base.crt"

REM Доверенные лица
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\esp.crt"
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\gismt.crt"
certutil -addstore "TrustedPeople" "C:\ProgramData\ESP\ESM\um\server.crt"

echo.
echo Сертификаты установлены.

:: =======================================
:: PIOT INSTALL FLOW
:: =======================================
echo.
echo ========================================
echo DOWNLOADING ZIP
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc=New-Object Net.WebClient; $wc.Credentials=New-Object Net.NetworkCredential('%USER%','%PASS%'); $wc.DownloadFile('ftp://rustdesk.olservice.ru/files/Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip','%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip')"

set "PLUGINS_DIR=C:\Program Files\iiko\iikoRMS\Front.Net\Plugins"
set "FRONT_DIR=C:\Program Files\iiko\iikoRMS\Front.Net"
set "ZIP_FILE=%WORKDIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip"
set "DESKTOP=%USERPROFILE%\Desktop"

echo ========================================
echo STOP IIKO FRONT
echo ========================================
taskkill /f /im iikoFront.Net.exe /T >nul 2>&1

echo.
echo ========================================
echo BACKUP OLD PLUGIN
echo ========================================

set "FOUND=0"

for /d %%D in ("%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin*") do (
    set "FOUND=1"
    echo Moving %%D to Desktop
    move "%%D" "%DESKTOP%" >nul 2>&1
)

if "!FOUND!"=="0" (
    echo No old plugin found, skipping backup
)


echo.
echo ========================================
echo COPY ZIP
echo ========================================

copy /y "%ZIP_FILE%" "%PLUGINS_DIR%" >nul

echo.
echo ========================================
echo EXTRACT ZIP
echo ========================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281.zip' '%PLUGINS_DIR%\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281'"

echo.
echo ========================================
echo START IIKO FRONT
echo ========================================

start "" "%FRONT_DIR%\iikoFront.Net.exe"

echo Waiting for config.json...

set "CONFIG_FILE=C:\Users\admin\AppData\Roaming\iiko\CashServer\PluginConfigs\Resto.Front.Api.OnlineMarkingVerificationPlugin.V9Preview6.1.0.281\config.json"

call :wait_for_file "%CONFIG_FILE%" 300

if errorlevel 1 (
    echo ERROR: config.json not created in time
    exit /b 1
)

echo Config detected!

echo DONE
goto CLEANUP

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
set "WORKDIR=C:\Temp\LMInstall"
set "TOKEN_FILE=%WORKDIR%\token.txt".

if not exist "%TOKEN_FILE%" (
    echo ERROR: token not found
    exit /b 1
)

set /p TOKEN=<"%TOKEN_FILE%"

set HOST=127.0.0.1
set PORT=5995
set LOGIN=admin
set PASSWORD=admin

echo.
echo =========================
echo СТАТУС
echo =========================

powershell -NoProfile -ExecutionPolicy Bypass "& {$pair='%LOGIN%:%PASSWORD%';$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair));$headers=@{Authorization='Basic '+$auth};try{Invoke-RestMethod -Uri 'http://%HOST%:%PORT%/api/v2/status' -Method Get -Headers $headers | ConvertTo-Json -Depth 10}catch{Write-Host 'Ошибка:';Write-Host $_.Exception.Message}}"

timeout /t 10 >nul
goto CLEANUP

:: =======================================
:: EXIT
:: =======================================
:EXIT
echo.
echo Выход...
timeout /t 2 >nul
exit /b