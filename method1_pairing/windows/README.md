# Illumio VEN — 方式一：使用官方配對腳本 (Windows)

> 適用於：Windows Server 2016 / 2019 / 2022、Windows 10 / 11  
> 最後更新：2026-03-05

---

## 概述

此方式使用 Illumio 官方配對腳本 (`pair.ps1`)，腳本會自動從 PCE 下載 VEN 安裝程式並完成安裝與啟用。

**使用前必須先匯入自簽 CA 憑證**，否則下載配對腳本時會因 SSL 驗證失敗而報錯。

---

## 步驟一：匯入自簽 CA 憑證

### 方法 A：使用腳本自動匯入 (建議)

1. 以「**系統管理員身分**」開啟 PowerShell
2. 執行：

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File Import-RootCA.ps1
```

> 腳本會自動檢查憑證是否已匯入，若已存在則跳過。

### 方法 B：手動以 PowerShell 匯入

```powershell
# 1. 定義憑證內容
$certContent = @"
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
"@

# 2. 儲存為暫存檔
$tempCertPath = "$env:TEMP\illumio-ca.crt"
Set-Content -Path $tempCertPath -Value $certContent -Encoding Ascii

# 3. 匯入憑證
Import-Certificate -FilePath $tempCertPath -CertStoreLocation Cert:\LocalMachine\Root

# 4. 清除暫存檔
Remove-Item -Path $tempCertPath

Write-Host "憑證匯入完成。" -ForegroundColor Green
```

### 方法 C：透過 MMC 圖形介面

1. `Win + R` → 輸入 `mmc` → 確定
2. **檔案** → **新增/移除嵌入式管理單元** → 選擇「**憑證**」→ 新增
3. 選擇「**電腦帳戶**」→ 下一步 → 完成 → 確定
4. 展開「**受信任的根憑證授權單位**」→ 「**憑證**」
5. 右鍵 → **所有工作** → **匯入** → 選擇 `illumio-ca.crt`

### 驗證憑證

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*illumio*" }
```

---

## 步驟二：執行官方配對腳本

確認憑證已匯入後，執行 Illumio PCE 提供的配對指令：

```powershell
PowerShell -Command "& {Set-ExecutionPolicy -Scope process remotesigned -Force; Start-Sleep -s 3; Set-Variable -Name ErrorActionPreference -Value SilentlyContinue; [System.Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([System.Net.SecurityProtocolType], 3072); Set-Variable -Name ErrorActionPreference -Value Continue; (New-Object System.Net.WebClient).DownloadFile('https://<PCE_FQDN>:<PORT>/api/v27/software/ven/image?pair_script=pair.ps1&profile_id=<PROFILE_ID>', (echo $env:windir\temp\pair.ps1)); & $env:windir\temp\pair.ps1 -management-server <PCE_FQDN>:<PORT> -activation-code <ACTIVATION_CODE>;}"
```

> 請將 `<PCE_FQDN>:<PORT>`、`<PROFILE_ID>`、`<ACTIVATION_CODE>` 替換為實際值。

---

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| 配對腳本下載失敗 (SSL error) | 憑證未匯入，請重新執行步驟一 |
| `Set-ExecutionPolicy` 報錯 | 已在指令中包含 `-Scope process`，應自動處理 |
| 執行腳本出現「不允許執行指令碼」 | `Set-ExecutionPolicy Bypass -Scope Process` |
| 憑證匯入失敗 (Access is denied) | 以「系統管理員身分」執行 PowerShell |
