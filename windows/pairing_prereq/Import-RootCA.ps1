<#
.SYNOPSIS
    Illumio 自簽 Root CA 憑證匯入工具 (含防重複檢查)

.DESCRIPTION
    此腳本將自簽 CA 憑證匯入到「本機電腦\受信任的根憑證授權單位」。
    匯入前以 Thumbprint 檢查是否已存在，避免重複匯入。
    搭配 Illumio 官方配對腳本 (pair.ps1) 使用前，需先執行此腳本。

.PARAMETER CertFile
    可選。指定外部憑證檔案路徑。若不指定，使用腳本內嵌憑證。

.EXAMPLE
    .\Import-RootCA.ps1
    .\Import-RootCA.ps1 -CertFile "C:\certs\illumio-ca.crt"

.NOTES
    需要以系統管理員身分執行。
#>

param(
    [string]$CertFile = ""
)

$ErrorActionPreference = "Stop"

# ==========================================
# 內嵌憑證內容
# ==========================================
$EmbeddedCertContent = @"
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
"@

try {
    Write-Output "============================================"
    Write-Output " Illumio Root CA 憑證匯入工具"
    Write-Output "============================================"
    Write-Output ""

    # 準備憑證內容 (優先順序: -CertFile 參數 > 同目錄 illumio-ca.crt > 內嵌憑證)
    $localCertPath = Join-Path $PSScriptRoot "illumio-ca.crt"
    if ($CertFile -ne "" -and (Test-Path $CertFile)) {
        Write-Output "[INFO] 使用外部憑證檔案 (-CertFile): $CertFile"
        $certContent = Get-Content -Path $CertFile -Raw
    } elseif ($CertFile -eq "" -and (Test-Path $localCertPath)) {
        Write-Output "[INFO] 使用同目錄憑證檔案: $localCertPath"
        $certContent = Get-Content -Path $localCertPath -Raw
    } else {
        if ($CertFile -ne "") {
            Write-Warning "指定的憑證檔案不存在: $CertFile，改用內嵌憑證。"
        }
        Write-Output "[INFO] 使用內嵌憑證。"
        $certContent = $EmbeddedCertContent
    }

    # 儲存為暫存檔案
    $tempCertPath = "$env:TEMP\illumio-ca.crt"
    Set-Content -Path $tempCertPath -Value $certContent -Encoding Ascii

    # 計算 Thumbprint 並檢查是否已存在
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($tempCertPath)
    $thumbprint = $cert.Thumbprint
    Write-Output "[INFO] 憑證 Thumbprint: $thumbprint"
    Write-Output "[INFO] 憑證 Subject:    $($cert.Subject)"

    $existingCert = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Thumbprint -eq $thumbprint }

    if ($existingCert) {
        Write-Output ""
        Write-Output "[SKIP] 憑證已存在於受信任的根憑證授權單位中，無須重複匯入。"
    } else {
        Import-Certificate -FilePath $tempCertPath -CertStoreLocation "Cert:\LocalMachine\Root"
        Write-Output ""
        Write-Output "[SUCCESS] 憑證已成功匯入到「受信任的根憑證授權單位」。"
    }

    Remove-Item -Path $tempCertPath -Force -ErrorAction SilentlyContinue

    Write-Output ""
    Write-Output "[完成] 現在可以執行 Illumio 官方配對腳本。"
    Exit 0

} catch {
    Write-Error "[FAILURE] 憑證匯入失敗: $_"
    if ($_.Exception.Message -like "*Access is denied*") {
        Write-Warning "請以「系統管理員身分執行」PowerShell。"
    }
    Remove-Item -Path "$env:TEMP\illumio-ca.crt" -Force -ErrorAction SilentlyContinue
    Exit 1
}
