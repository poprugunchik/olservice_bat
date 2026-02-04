param([string]$UpdateTarget)

# =====================================================
# TLS FIX — С САМОГО НАЧАЛА
# =====================================================
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 `
        -bor [Net.SecurityProtocolType]::Tls11 `
        -bor [Net.SecurityProtocolType]::Tls
} catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =====================================================
# LOGGING
# =====================================================
$LogDir = Join-Path ([System.IO.Path]::GetTempPath()) "olservice_debug"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("debug_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Log {
    param([string]$Level,[string]$Message)
    try {
        Add-Content $LogFile ("[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Level,$Message) -Encoding UTF8
    } catch {}
}

Log INFO "=== OLService started ==="

# =====================================================
# PATHS
# =====================================================
$TempDir = [System.IO.Path]::GetTempPath()
$Desktop = [Environment]::GetFolderPath("Desktop")
$LocalExe = Join-Path $Desktop "OLService.exe"
$TempExe  = Join-Path $TempDir "OLService_new.exe"

$WorkDir = Join-Path $TempDir "olservice"
if (!(Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }

# =====================================================
# ADMIN CHECK
# =====================================================
function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    Log WARN "Restart as admin"
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# =====================================================
# UPDATER MODE (БЕЗ ПАРОЛЯ И GUI)
# =====================================================
if ($UpdateTarget) {
    Log INFO "Updater mode"

    $UpdaterBat = Join-Path $TempDir "updater.bat"

@"
@echo off
:wait
tasklist | find "OLService.exe" >nul
if %ERRORLEVEL%==0 (
  timeout /t 1 >nul
  goto wait
)
del /F /Q "$UpdateTarget"
copy /Y "$TempExe" "$UpdateTarget"
start "" "$UpdateTarget"
del /F /Q "$TempExe"
del /F /Q "%~f0"
"@ | Set-Content $UpdaterBat -Encoding ASCII

    Start-Process $UpdaterBat -WindowStyle Hidden
    exit
}

# =====================================================
# PASSWORD PROMPT WITH LAYOUT INDICATOR
# =====================================================
$CorrectPassword = "zxc123asd456"

function Prompt-Password {

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

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Авторизация"
    $form.Size = "400,180"
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Введите пароль:"
    $label.Location = "20,15"
    $form.Controls.Add($label)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = "20,50"
    $box.Size = "250,25"
    $box.UseSystemPasswordChar = $true
    $form.Controls.Add($box)

    $layoutLabel = New-Object System.Windows.Forms.Label
    $layoutLabel.Location = "290,50"
    $layoutLabel.Size = "70,25"
    $layoutLabel.Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
    $layoutLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($layoutLabel)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $timer.Add_Tick({
        $id = ([KeyboardLayout]::GetKeyboardLayout([KeyboardLayout]::GetCurrentThreadId())).ToInt64() -band 0xFFFF
        switch ($id) {
            0x409 { $layoutLabel.Text="ENG"; $layoutLabel.ForeColor="Green" }
            0x419 { $layoutLabel.Text="RU";  $layoutLabel.ForeColor="Red" }
            default { $layoutLabel.Text="???"; $layoutLabel.ForeColor="Black" }
        }
    })
    $timer.Start()

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "OK"
    $ok.Location = "70,100"
    $ok.Add_Click({ $form.DialogResult="OK"; $form.Close() })
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Отмена"
    $cancel.Location = "200,100"
    $cancel.Add_Click({ $form.DialogResult="Cancel"; $form.Close() })
    $form.Controls.Add($cancel)

    $res = $form.ShowDialog()
    $timer.Stop()

    if ($res -eq "OK") { return $box.Text }
    return $null
}

do {
    $input = Prompt-Password
    if ($input -eq $null) { Log INFO "Password cancelled"; exit }
    if ($input -ne $CorrectPassword) {
        Log WARN "Wrong password"
        [System.Windows.Forms.MessageBox]::Show("Неверный пароль","Ошибка")
    }
} while ($input -ne $CorrectPassword)

Log INFO "Password accepted"

# =====================================================
# DOWNLOAD FUNCTION
# =====================================================
$Headers = @{ "User-Agent"="OLService-Launcher" }

function Download-File($Url,$Out) {
    try {
        Invoke-WebRequest $Url -OutFile $Out -Headers $Headers -UseBasicParsing -TimeoutSec 30
        return $true
    } catch {}
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        curl.exe -L $Url -o $Out
        return (Test-Path $Out)
    }
    return $false
}

# =====================================================
# VERSION CHECK & AUTOUPDATE
# =====================================================
$VersionUrl = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/version.txt"
$ExeUrl     = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/dist/OLService.exe"

$CurrentVersion = if (Test-Path $LocalExe) {
    (Get-Item $LocalExe).VersionInfo.ProductVersion
} else { "1.0" }

try {
    $LatestVersion = (Invoke-WebRequest $VersionUrl -Headers $Headers -UseBasicParsing).Content.Trim()
} catch {
    $LatestVersion = $CurrentVersion
}

function Is-Newer($c,$l) {
    $cv=$c.Split('.')|%{[int]$_}
    $lv=$l.Split('.')|%{[int]$_}
    for($i=0;$i -lt [Math]::Max($cv.Count,$lv.Count);$i++){
        if(($lv[$i]??0) -gt ($cv[$i]??0)){return $true}
        if(($lv[$i]??0) -lt ($cv[$i]??0)){return $false}
    }
    return $false
}

if (Is-Newer $CurrentVersion $LatestVersion) {
    if ([System.Windows.Forms.MessageBox]::Show(
        "Доступна новая версия ($LatestVersion). Обновить?",
        "Обновление","YesNo","Information"
    ) -eq "Yes") {

        if (Download-File $ExeUrl $TempExe) {
            Start-Process $TempExe -ArgumentList "-UpdateTarget `"$LocalExe`"" -Verb RunAs
            exit
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ошибка загрузки обновления","Ошибка")
        }
    }
}

# =====================================================
# MAIN GUI
# =====================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "OLService Launcher"
$form.Size = "420,300"
$form.StartPosition = "CenterScreen"

$list = New-Object System.Windows.Forms.ListBox
$list.Location = "20,40"
$list.Size = "360,140"
$list.Items.AddRange(@(
    "RustDesk — Установить клиент",
    "iikoCard — Работа с iikocard",
    "Clean — Очистка временных файлов",
    "Framework+chz — установка ЧЗ и фреймворков",
    "Прошу тебя только не нажимай сюда!",
    "OrderCheck — запуск"
))
$form.Controls.Add($list)

$run = New-Object System.Windows.Forms.Button
$run.Text = "Запустить"
$run.Location = "70,200"
$run.Size = "120,40"
$form.Controls.Add($run)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "Отмена"
$cancel.Location = "220,200"
$cancel.Size = "120,40"
$cancel.Add_Click({ $form.Close() })
$form.Controls.Add($cancel)

$Repo = "https://raw.githubusercontent.com/poprugunchik/olservice_bat/main/scripts"

$run.Add_Click({
    if ($list.SelectedIndex -lt 0) { return }

    $map = @{
        0="rustdesk.bat"
        1="iikocard.bat"
        2="clean.bat"
        3="chz.bat"
        4="update_service.exe"
        5="ordercheck.bat"
    }

    $Script = $map[$list.SelectedIndex]
    $Local  = Join-Path $WorkDir $Script

    if (!(Test-Path $Local)) {
        if (-not (Download-File "$Repo/$Script" $Local)) {
            [System.Windows.Forms.MessageBox]::Show("Не удалось скачать $Script","Ошибка")
            return
        }
    }

    Start-Process $Local -Verb RunAs -WorkingDirectory $WorkDir
})

[void]$form.ShowDialog()
Log INFO "Launcher closed"
