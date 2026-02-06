@echo off
chcp 1251 >nul
setlocal enabledelayedexpansion


:: Проверяем, есть ли curl в системе
where curl >nul 2>&1
if %errorlevel%==0 (
    echo curl уже установлен.
    curl --version
    pause
    exit /b 0
)

echo curl не найден

:: Папка, куда скачиваем curl
set "CURL_DIR=C:\iiko\curl"

if not exist "%CURL_DIR%" mkdir "%CURL_DIR%"

echo Включаем поддержку TLS 1.2...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"

echo Скачиваем curl...
powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(1251); [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://curl.se/windows/dl-8.6.0_3/curl-8.6.0_3-win64-mingw.zip' -OutFile '%CURL_DIR%\curl.zip'"

if exist "%CURL_DIR%\curl.zip" (
    echo Распаковываем...
    powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(1251); Expand-Archive -Path '%CURL_DIR%\curl.zip' -DestinationPath '%CURL_DIR%' -Force"
) else (
    echo Ошибка: curl.zip не найден. Скачивание не удалось.
    pause
    exit /b 1
)

:: Находим путь к curl.exe
set "CURL_EXE=%CURL_DIR%\curl-8.6.0_3-win64-mingw\bin"

:: Добавляем в PATH текущей сессии
set PATH=%CURL_EXE%;%PATH%

:: Добавляем в PATH навсегда (для пользователя)
echo Добавляем curl в PATH...
setx PATH "%CURL_EXE%;%PATH%"

echo Готово! Проверьте: curl --version
pause
