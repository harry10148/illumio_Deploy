# Illumio VEN — 方式二：手動安裝 + 手動回報 (Windows)

> 適用於：Windows Server 2016 / 2019 / 2022、Windows 10 / 11  
> 最後更新：2026-03-05

---

## 概述

此方式使用 VEN `.exe` 安裝程式直接安裝，安裝後手動執行啟用指令向 PCE 回報。

**提供兩種腳本版本：**
- `Deploy-Illumio.ps1` — PowerShell 版 (支援參數化自訂安裝路徑)
- `deploy-illumio.bat` — Batch 版 (修改腳本內變數)

---

## 使用腳本自動安裝 (包含 SCCM 部署支援)

本專案的 PowerShell 與 Batch 腳本皆支援 **SCCM 靜默部署 (Silent Deployment)**。腳本執行時會：
1. 完全不跳出任何互動視窗
2. 將所有產出日誌寫入至 `%TEMP%\IllumioDeploy.log` (方便 SCCM SYSTEM 帳戶除錯)
3. 確實返回 Exit Code 以利 SCCM 判斷安裝成功或失敗

### PowerShell 版

```powershell
# 預設路徑安裝 (SCCM 執行指令)
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File Deploy-Illumio.ps1 -ActivationCode "<CODE>" -ManagementServer "<PCE_FQDN>:<PORT>"

# 自訂安裝路徑
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File Deploy-Illumio.ps1 -InstallDir "D:\Illumio" -DataDir "D:\Illumio_Data" -ActivationCode "<CODE>" -ManagementServer "<PCE_FQDN>:<PORT>"
```

### Batch 版

1. 用文字編輯器打開 `deploy-illumio.bat`
2. 修改設定區的變數：`EXE_FILE`、`ACTIVATION_CODE`、`MANAGEMENT_SERVER`、`INSTALL_DIR`
3. SCCM 執行指令直接設定為：
```cmd
cmd.exe /c deploy-illumio.bat
```

---

## 全手動安裝步驟

### 步驟一：匯入自簽 CA 憑證

以管理員身分開啟 PowerShell：

```powershell
$certContent = @"
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
"@

$tempCertPath = "$env:TEMP\illumio-ca.crt"
Set-Content -Path $tempCertPath -Value $certContent -Encoding Ascii
Import-Certificate -FilePath $tempCertPath -CertStoreLocation Cert:\LocalMachine\Root
Remove-Item -Path $tempCertPath
```

### 步驟二：安裝 VEN

```powershell
# 預設路徑
.\25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe /install /quiet /norestart

# 自訂路徑
.\25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe /install /quiet /norestart INSTALLDIR="D:\Illumio" DATDIR="D:\Illumio_Data"
```

### 步驟三：啟用 (手動回報)

```powershell
& "C:\Program Files\Illumio\illumio-ven-ctl.exe" activate `
    -activation-code <ACTIVATION_CODE> `
    -management-server <PCE_FQDN>:<PORT>
```

### 步驟四：驗證

```powershell
Get-Service -Name "IllumioVEN" -ErrorAction SilentlyContinue
& "C:\Program Files\Illumio\illumio-ven-ctl.exe" status
```

---

## 疑難排解與日誌

無論是 PowerShell 或 Batch 腳本，**所有執行過程皆會記錄於**：
👉 `%TEMP%\IllumioDeploy.log`  *(若透過 SCCM 以 SYSTEM 執行，通常位於 `C:\Windows\Temp\IllumioDeploy.log`)*

| 問題 | 解決方式 |
|------|---------|
| 安裝後找不到 `illumio-ven-ctl.exe` | 查看 `%TEMP%\IllumioDeploy.log` 確認安裝檔的 Exit Code，檢查是否被防毒阻擋 |
| 啟用失敗 | 確認憑證已匯入、可連線至 PCE、Activation Code 有效 |
| 執行策略限制 | 確認 PowerShell 指令加上了 `-ExecutionPolicy Bypass` |
