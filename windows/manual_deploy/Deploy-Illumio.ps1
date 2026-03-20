<#
.SYNOPSIS
    Illumio VEN Agent 自動部署腳本 — 方式二：手動安裝 (PowerShell)

.DESCRIPTION
    1. 匯入自簽 Root CA 憑證 (Thumbprint 防重複)
    2. 以指定目錄安裝 VEN Agent (靜默安裝)
    3. 執行 activation 回報至 PCE

.PARAMETER InstallDir
    VEN 安裝目錄。預設: "C:\Program Files\Illumio"

.PARAMETER DataDir
    VEN 資料目錄。預設: "C:\ProgramData\Illumio"

.PARAMETER ExeFile
    VEN 安裝程式檔名 (需與腳本在同一目錄，除非指定 SourceDir)

.PARAMETER SourceDir
    安裝檔所在目錄。預設為空 (自動帶入腳本所在目錄)

.PARAMETER ActivationCode
    Activation Code

.PARAMETER ManagementServer
    PCE 管理伺服器 (FQDN:PORT)

.EXAMPLE
    .\Deploy-Illumio.ps1
    .\Deploy-Illumio.ps1 -InstallDir "D:\Illumio" -DataDir "D:\Illumio_Data"

.NOTES
    需要以系統管理員身分執行。
#>

param(
    [string]$InstallDir       = "C:\Program Files\Illumio",
    [string]$DataDir          = "C:\ProgramData\Illumio",
    [string]$SourceDir        = "",
    [string]$ExeFile          = "",
    [string]$ActivationCode   = "<YOUR_ACTIVATION_CODE>",
    [string]$ManagementServer = "<YOUR_PCE_FQDN:PORT>"
)

$ErrorActionPreference = "Stop"

# ==========================================
# 內嵌憑證
# ==========================================
$EmbeddedCertContent = @"
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
"@

$LogFile = "$env:TEMP\IllumioDeploy.log"

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$ts] [$Level] $Message"
    
    # 輸出到主控台 (適用於手動執行)
    $color = switch ($Level) { "INFO" {"Cyan"} "OK" {"Green"} "SKIP" {"Yellow"} "ERROR" {"Red"} default {"White"} }
    Write-Host $logMsg -ForegroundColor $color
    
    # 輸出到日誌檔案 (適用於 SCCM 背景執行)
    Add-Content -Path $LogFile -Value $logMsg -ErrorAction SilentlyContinue
}

try {
    Write-Log "INFO" "============================================"
    Write-Log "INFO" " Illumio VEN — 方式二：手動安裝部署腳本"
    Write-Log "INFO" "============================================"
    Write-Log "INFO" "日誌檔案: $LogFile"
    Write-Log "INFO" "安裝目錄: $InstallDir"
    Write-Log "INFO" "資料目錄: $DataDir"

    # === Step 1: 匯入憑證 ===
    Write-Log "INFO" ""
    Write-Log "INFO" "[Step 1/3] 檢查並匯入自簽 CA 憑證..."

    # 優先使用腳本同目錄下的 illumio-ca.crt，若有則覆蓋內嵌憑證
    $localCertPath = Join-Path $PSScriptRoot "illumio-ca.crt"
    if (Test-Path $localCertPath) {
        Write-Log "INFO" "使用同目錄憑證檔案: $localCertPath"
        $EmbeddedCertContent = Get-Content -Path $localCertPath -Raw
    }

    $tempCertPath = "$env:TEMP\illumio-ca.crt"
    Set-Content -Path $tempCertPath -Value $EmbeddedCertContent -Encoding Ascii
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($tempCertPath)
    $thumbprint = $cert.Thumbprint
    Write-Log "INFO" "Thumbprint: $thumbprint"

    $existing = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Thumbprint -eq $thumbprint }
    if ($existing) {
        Write-Log "SKIP" "憑證已存在，跳過匯入。"
    } else {
        Import-Certificate -FilePath $tempCertPath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
        Write-Log "OK" "憑證匯入成功。"
    }
    Remove-Item -Path $tempCertPath -Force -ErrorAction SilentlyContinue

    # === Step 2: 安裝 VEN ===
    Write-Log "INFO" ""
    Write-Log "INFO" "[Step 2/3] 安裝 Illumio VEN Agent..."

    if (-not [string]::IsNullOrEmpty($SourceDir)) {
        $ScriptPath = $SourceDir
    } else {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    # ExeFile 留空時，自動偵測 SourceDir 內唯一的 .exe
    if ([string]::IsNullOrEmpty($ExeFile)) {
        $foundExe = Get-ChildItem -Path $ScriptPath -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $foundExe) { Throw "在 $ScriptPath 找不到 .exe 安裝檔，請指定 -ExeFile 參數。" }
        $ExeFile = $foundExe.Name
        Write-Log "INFO" "自動偵測安裝檔: $ExeFile"
    }

    $InstallerPath = Join-Path $ScriptPath $ExeFile

    if (-not (Test-Path $InstallerPath)) {
        Throw "找不到安裝檔: $InstallerPath"
    }

    $defaultDir = "C:\Program Files\Illumio"
    if ($InstallDir -eq $defaultDir) {
        $args = @("/install", "/quiet", "/norestart")
    } else {
        $args = @("/install", "/quiet", "/norestart", "INSTALLDIR=`"$InstallDir`"", "DATDIR=`"$DataDir`"")
    }

    Write-Log "INFO" "安裝檔: $InstallerPath"
    $proc = Start-Process -FilePath $InstallerPath -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -ne 0) { Throw "安裝失敗。Exit Code: $($proc.ExitCode)" }
    Write-Log "OK" "VEN Agent 安裝完成。"

    # === Step 3: 啟用 ===
    Write-Log "INFO" ""
    Write-Log "INFO" "[Step 3/3] 啟用 VEN Agent..."

    $TargetCtl = Join-Path $InstallDir "illumio-ven-ctl.exe"
    if (-not (Test-Path $TargetCtl)) { $TargetCtl = "C:\Program Files\Illumio\illumio-ven-ctl.exe" }
    if (-not (Test-Path $TargetCtl)) { Throw "找不到 illumio-ven-ctl.exe" }

    if ($ActivationCode -eq "<YOUR_ACTIVATION_CODE>" -or $ManagementServer -eq "<YOUR_PCE_FQDN:PORT>") {
        Throw "請先設定 ActivationCode 和 ManagementServer 參數。"
    }

    & $TargetCtl activate -activation-code $ActivationCode -management-server $ManagementServer
    Write-Log "OK" "啟用指令已送出。"

    Write-Log "OK" ""
    Write-Log "OK" "部署完成！"
    Exit 0

} catch {
    Write-Log "ERROR" "部署失敗: $_"
    Exit 1
}
