param(
    [string]$UpdateTarget
)


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# =====================================
# ПОЛНОЕ ЛОГИРОВАНИЕ С САМОГО НАЧАЛА
# =====================================
$LogDir = Join-Path ([System.IO.Path]::GetTempPath()) "olservice_debug"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "debug_$Timestamp.log"

function Log {
    param ([string]$Level, [string]$Message)
    try {
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch { }
}

Log INFO "=== Запуск OLService ==="


# =====================================
# UPDATER MODE
# =====================================
if ($UpdateTarget) {
    Log INFO "Updater mode. Target: $UpdateTarget"

    Start-Sleep -Seconds 2

    $replaced = $false

	for ($i = 0; $i -lt 10; $i++) {
		try {
			Copy-Item -Path $PSCommandPath -Destination $UpdateTarget -Force
			Log INFO "Exe successfully replaced"
			$replaced = $true
			break
		} catch {
			Log WARN "File is locked, waiting..."
			Start-Sleep -Seconds 1
		}
	}

	if (-not $replaced) {
		Log ERROR "Не удалось заменить exe после 10 попыток"
		exit
	}

	Start-Process -FilePath $UpdateTarget -Verb RunAs
	exit
}

# =====================================
# БЕЗОПАСНОЕ ОПРЕДЕЛЕНИЕ ПУТЕЙ
# =====================================
# TEMP
if ($env:TEMP) { $TempDir = $env:TEMP } else { $TempDir = [System.IO.Path]::GetTempPath() }
if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }
Log INFO "TempDir: $TempDir"

# USERPROFILE / Desktop
if ($env:USERPROFILE) { $UserDir = $env:USERPROFILE } else {
    try { $UserDir = [Environment]::GetFolderPath("Desktop") } catch { $UserDir = $TempDir }
}
Log INFO "UserDir: $UserDir"

# Пути
$Desktop = [Environment]::GetFolderPath("Desktop")
$LocalExe = Join-Path $Desktop "OLService.exe"
$TempExe  = Join-Path $TempDir "OLService_new.exe"
if ($PSScriptRoot) { $ScriptRoot = $PSScriptRoot } else { $ScriptRoot = $TempDir }

Log INFO "LocalExe: $LocalExe"
Log INFO "TempExe: $TempExe"
Log INFO "ScriptRoot: $ScriptRoot"

# =====================================
# Текущая версия из EXE
# =====================================
$LocalExe = Join-Path $Desktop "OLService.exe"

if (Test-Path $LocalExe) {
    $CurrentVersion = (Get-Item $LocalExe).VersionInfo.ProductVersion
} else {
    $CurrentVersion = "1.0"  # дефолт, если exe нет
}

Log INFO "CurrentVersion (from exe properties): $CurrentVersion"


# GitHub ссылки
$VersionUrl = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/version.txt"
$ExeUrl = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/dist/olservice.exe"

# =====================================
# ФУНКЦИЯ ПРОВЕРКИ ВЕРСИИ С ЛОГОМ
# =====================================
function Is-NewerVersion {
    param (
        [string]$current,
        [string]$latest
    )

    Log INFO "Сравниваем версии: current=$current, latest=$latest"

    # Проверка формата
    if (-not ($current -match '^\d+(\.\d+)*$')) {
        Log WARN "Неверный формат текущей версии: $current"
        return $false
    }
    if (-not ($latest -match '^\d+(\.\d+)*$')) {
        Log WARN "Неверный формат версии с сервера: $latest"
        return $false
    }

    $cur = $current.Split(".") | ForEach-Object {[int]$_}
    $lat = $latest.Split(".") | ForEach-Object {[int]$_}

    for ($i = 0; $i -lt [Math]::Max($cur.Count, $lat.Count); $i++) {
        $c = if ($i -lt $cur.Count) {$cur[$i]} else {0}
        $l = if ($i -lt $lat.Count) {$lat[$i]} else {0}
        if ($l -gt $c) {
            Log INFO "Версия сервера новее (latest > current)"
            return $true
        }
        if ($l -lt $c) {
            Log INFO "Локальная версия новее или серверная версия старше (current > latest)"
            return $false
        }
    }

    Log INFO "Версии равны"
    return $false
}

# =====================================
# ПРОВЕРКА ВЕРСИИ С СЕРВЕРА
# =====================================
try {
    $LatestVersionRaw = (Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing).Content
    # Убираем BOM и всё лишнее
    $LatestVersion = $LatestVersionRaw -replace '^\uFEFF',''
    $LatestVersion = ($LatestVersion -match '[\d\.]+')[0]  # оставляем только цифры и точки
    Log INFO "LatestVersion получена: $LatestVersion"
} catch {
    Log ERROR "Не удалось получить версию с GitHub: $($_.Exception.Message)"
    $LatestVersion = $CurrentVersion
}

if (Is-NewerVersion $CurrentVersion $LatestVersion) {
    Log INFO "Доступна новая версия: $LatestVersion"
    # Здесь можно запускать логику обновления
} else {
    Log INFO "Обновление не требуется. Текущая версия: $CurrentVersion, серверная версия: $LatestVersion"
}

# =====================================
# ПРОВЕРКА ADMIN
# =====================================
function Is-Admin {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Log INFO "IsAdmin: $isAdmin"
    return $isAdmin
}

if (-not (Is-Admin)) {
    Log WARN "Не админ, перезапуск с правами администратора"
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Log INFO "Запущен с правами администратора"

# =====================================
# ОБНОВЛЕНИЕ EXE
# =====================================
try {
    $LatestVersion = (Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing).Content.Trim()
    Log INFO "LatestVersion: $LatestVersion"
} catch {
    Log ERROR "Не удалось получить версию с GitHub: $($_.Exception.Message)"
    $LatestVersion = $CurrentVersion
}

if (Is-NewerVersion $CurrentVersion $LatestVersion) {
    Log INFO "Доступна новая версия: $LatestVersion, текущая: $CurrentVersion"

    $update = [System.Windows.Forms.MessageBox]::Show(
        "Доступна новая версия ($LatestVersion). Обновить сейчас?",
        "Обновление",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    if ($update -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Log INFO "Скачиваем новую версию exe..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $ExeUrl -OutFile $TempExe
            Log INFO "Скачивание завершено: $TempExe"

            if (!(Test-Path $TempExe)) {
                throw "TempExe не найден после скачивания"
            }

            Log INFO "Запускаем updater"
            Start-Process -FilePath $TempExe `
				-ArgumentList "-UpdateTarget `"$LocalExe`"" `
				-Verb RunAs


            exit   # ⬅️ ОБЯЗАТЕЛЬНО
        } catch {
            Log ERROR "Ошибка обновления exe: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show(
                "Не удалось обновить exe: $($_.Exception.Message)",
                "Ошибка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            exit
        }
    } else {
        Log INFO "Пользователь отказался обновлять exe"
    }
} else {
    Log INFO "Обновление не требуется, текущая версия актуальна"
}


# =====================================
# ФОРМА ПАРОЛЯ
# =====================================
function Prompt-Password {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Авторизация"
    $form.Size = New-Object System.Drawing.Size(400,180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Введите пароль (английская раскладка):"
    $label.Location = New-Object System.Drawing.Point(20,15)
    $label.AutoSize = $true
    $form.Controls.Add($label)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point(20,50)
    $box.Size = New-Object System.Drawing.Size(250,25)
    $box.UseSystemPasswordChar = $true
    $form.Controls.Add($box)

    $layoutLabel = New-Object System.Windows.Forms.Label
    $layoutLabel.Location = New-Object System.Drawing.Point(280,50)
    $layoutLabel.Size = New-Object System.Drawing.Size(80,25)
    $layoutLabel.Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
    $layoutLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($layoutLabel)

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyboardLayout {
    [DllImport("user32.dll")]
    public static extern IntPtr GetKeyboardLayout(uint idThread);
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
}
"@

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $timer.Add_Tick({
        $layout = [KeyboardLayout]::GetKeyboardLayout([KeyboardLayout]::GetCurrentThreadId())
        $layoutId = $layout.ToInt64() -band 0xFFFF
        if ($layoutId -eq 0x409) { $layoutLabel.Text = "ENG"; $layoutLabel.ForeColor = [System.Drawing.Color]::Green }
        elseif ($layoutId -eq 0x419) { $layoutLabel.Text = "RU"; $layoutLabel.ForeColor = [System.Drawing.Color]::Red }
        else { $layoutLabel.Text = "???"; $layoutLabel.ForeColor = [System.Drawing.Color]::Black }
    })
    $timer.Start()

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "OK"
    $ok.Location = New-Object System.Drawing.Point(70,100)
    $ok.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK; $form.Close() })
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Отмена"
    $cancel.Location = New-Object System.Drawing.Point(200,100)
    $cancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
    $form.Controls.Add($cancel)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -eq "OK") { $timer.Stop(); return $box.Text } else { $timer.Stop(); return $null }
}

# =====================================
# ПРОВЕРКА ПАРОЛЯ
# =====================================
$CorrectPassword = "zxc123asd456"
do {
    $input = Prompt-Password
    if ($input -eq $null) { Log INFO "Пользователь отменил ввод пароля"; exit }
    if ($input -ne $CorrectPassword) {
        Log WARN "Wrong password"
        [System.Windows.Forms.MessageBox]::Show("Неверный пароль","Ошибка",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
} while ($input -ne $CorrectPassword)
Log INFO "Password accepted"

# =====================================
# ОСНОВНОЙ GUI
# =====================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "OLService Launcher"
$form.Size = New-Object System.Drawing.Size(420,300)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Выберите действие:"
$label.Location = New-Object System.Drawing.Point(20,20)
$label.AutoSize = $true
$form.Controls.Add($label)

$list = New-Object System.Windows.Forms.ListBox
$list.Location = New-Object System.Drawing.Point(20,50)
$list.Size = New-Object System.Drawing.Size(360,120)
$list.Items.AddRange(@(
    "RustDesk — Установить клиент",
    "iikoCard — Работа с iikocard",
    "Clean — Очистка временных файлов",
    "Framework+chz — установка ЧЗ и фреймворков",
	"Прошу тебя только не нажимай сюда!"
))
$form.Controls.Add($list)

$run = New-Object System.Windows.Forms.Button
$run.Text = "Запустить"
$run.Location = New-Object System.Drawing.Point(70,200)
$run.Size = New-Object System.Drawing.Size(120,40)
$form.Controls.Add($run)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "Отмена"
$cancel.Location = New-Object System.Drawing.Point(220,200)
$cancel.Size = New-Object System.Drawing.Size(120,40)
$cancel.Add_Click({ $form.Close() })
$form.Controls.Add($cancel)

# =====================================
# ЗАПУСК BAT-СКРИПТОВ
# =====================================
$run.Add_Click({
    if ($list.SelectedIndex -lt 0) {
        [System.Windows.Forms.MessageBox]::Show("Выберите действие","Внимание",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $Repo = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/scripts"
    $WorkDir = Join-Path $TempDir "olservice"
    if (!(Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
    Log INFO "WorkDir: $WorkDir"

    switch ($list.SelectedIndex) {
        0 { $Script = "rustdesk.bat" }
        1 { $Script = "iikocard.bat" }
        2 { $Script = "clean.bat" }
        3 { $Script = "chz.bat" }
		4 { $Script = "update_service.exe" }
        default { [System.Windows.Forms.MessageBox]::Show("Выберите действие","Внимание",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning); return }
    }

    $Local = Join-Path $WorkDir $Script
    Log INFO "Local script: $Local"

    if (!(Test-Path $Local) -or ((Get-Date) - (Get-Item $Local).LastWriteTime).TotalHours -gt 24) {
        try {
            Log INFO "Downloading $Script from $Repo"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri "$Repo/$Script" -OutFile $Local
            Log INFO "Download complete: $Local"
        } catch {
            Log ERROR "Download failed: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Не удалось скачать $Script","Ошибка",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    }

    if (!(Test-Path $Local)) {
        Log ERROR "File not found: $Local"
        [System.Windows.Forms.MessageBox]::Show("Скрипт не найден: $Local","Ошибка",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    Log INFO "Starting $Script"
    Start-Process -FilePath $Local -Verb RunAs -WorkingDirectory $WorkDir
})

[void]$form.ShowDialog()
Log INFO "Launcher closed"
