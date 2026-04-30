# Illumio VEN — 完整手動部署 (Windows)

> 適用於：Windows Server 2016 / 2019 / 2022、Windows 10 / 11  
> 最後更新：2026-04-24

---

## 前置需求

| 項目 | 需求 |
|------|------|
| **磁碟空間** | 保留至少 **10 GB** 供 VEN 使用 |
| **時間同步** | Windows Time Service (W32tm) 必須正常運作 |
| **網路連線** | 能連至 PCE：本地部署 TCP **8443**（REST API）+ **8444**（長連線）；SaaS 部署 TCP **443** |
| **TLS 版本** | 最低支援 **TLS 1.2**（Windows Server 2016+ / Windows 10 1607+ 在 Schannel 預設啟用；舊版需手動開啟或由配對腳本以 `[Enum]::ToObject([SecurityProtocolType], 3072)` 強制指定） |
| **執行權限** | 安裝需以 **系統管理員** 身分執行 |

> **TLS 攔截注意**：若路徑上有 TLS 攔截裝置（MITM），請針對 VEN ↔ PCE 流量**關閉 TLS 檢查**，否則憑證鏈不完整將導致連線失敗。
>
> **SecureConnect 注意**：若日後啟用 Illumio SecureConnect (VEN 之間 IPsec 加密)，需額外開放 **UDP 500** 與 **UDP 4500**（IKE/NAT-T）。

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
# 預設路徑安裝 (自動尋找與腳本同目錄下的 EXE)
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File Deploy-Illumio.ps1 -ActivationCode "<CODE>" -ManagementServer "<PCE_FQDN>:<PORT>"

# 指定安裝檔來源目錄與自訂安裝路徑
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File Deploy-Illumio.ps1 -SourceDir "Z:\Installers" -InstallDir "D:\Illumio" -DataDir "D:\Illumio_Data" -ActivationCode "<CODE>" -ManagementServer "<PCE_FQDN>:<PORT>"
```

### Batch 版

1. 用文字編輯器打開 `deploy-illumio.bat`
2. 修改設定區的變數：`EXE_FILE`、`SOURCE_DIR` (可選，留空則為同目錄)、`ACTIVATION_CODE`、`MANAGEMENT_SERVER`、`INSTALL_DIR`
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
.\25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe /install /quiet /norestart /log "%TEMP%\IllumioVENInstall.log"

# 自訂路徑（注意：屬性名稱為 INSTALLFOLDER / DATAFOLDER，非 INSTALLDIR / DATDIR）
.\25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe /install /quiet /norestart /log "%TEMP%\IllumioVENInstall.log" INSTALLFOLDER="D:\Illumio" DATAFOLDER="D:\Illumio_Data"
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

### PowerShell 參數說明
| 參數名 | 說明 |
|---|---|
| `ActivationCode` | (必填) 您的 Activation Code |
| `ManagementServer` | (必填) PCE 管理節點與 Port，例如 `pce.example.com:8443` |
| `InstallDir` | VEN 安裝目錄 (選填)，預設 `C:\Program Files\Illumio` |
| `DataDir` | VEN 資料儲存目錄 (選填)，預設 `C:\ProgramData\Illumio` |
| `SourceDir` | VEN 安裝檔 `.exe` 所在目錄 (選填)，預設自動帶入腳本所在位置 |
| `ExeFile` | 安裝檔名 (選填)，預設 `25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe` |

---

## 卸載（Unpair + 移除）

> **建議順序：先 Unpair → 再移除**

### 方法一：使用 VEN CLI（建議）

以系統管理員身分開啟 PowerShell 或命令提示字元：

```powershell
& "C:\Program Files\Illumio\illumio-ven-ctl.exe" unpair [recommended | saved | open]
```

| 模式 | 說明 | 安全考量 |
|------|------|----------|
| `recommended` | 解除後僅開放 RDP (3389) 及 WinRM (5985/5986)，直到重新開機 | 若主機有其他服務，解除後將無法連線 |
| `saved` | 解除後移除 Illumio WFP 過濾規則，還原 Windows 原生防火牆 | 適合一般生產環境 |
| `open` | 解除後開放所有埠 | 高風險，僅用於隔離環境 |
| `unmanaged` | 僅用於從未配對至 PCE 的 VEN，防火牆狀態維持不變 | — |

### 方法二：透過 Windows 控制台

1. 開啟「**控制台**」→「**程式和功能**」（或「新增/移除程式」）
2. 找到 **Illumio VEN** → 點選「**解除安裝**」

> 透過控制台移除時，系統預設以 `saved` 模式處理（移除 Illumio WFP 規則並重新啟用原生 Windows 防火牆）。

### 方法三：從 PCE Web Console 遠端解除

1. 登入 PCE Web Console → **Servers & Endpoints > Workloads**
2. 切換至「**VENs**」分頁 → 選取目標主機
3. 點選「**Unpair**」→ 選擇防火牆最終狀態 → 確認
