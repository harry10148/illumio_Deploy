# Illumio VEN — 完整手動部署 (Linux)

> 適用於：RHEL 7/8/9、CentOS 7、Rocky Linux、AlmaLinux、Ubuntu、Debian  
> 最後更新：2026-04-24

---

## 前置需求

| 項目 | 需求 |
|------|------|
| **磁碟空間** | 保留至少 **10 GB** 供 VEN 使用 |
| **時間同步** | NTP 必須正常運作（PCE 與 VEN 時間偏差過大會導致 TLS 握手失敗） |
| **網路連線** | 能連至 PCE：本地部署 TCP **8443**（REST API）+ **8444**（長連線）；SaaS 部署 TCP **443** |
| **TLS 版本** | 最低支援 **TLS 1.2** |
| **憑證信任** | 需匯入 PCE 根 CA 憑證，確保 VEN 可驗證 PCE 的憑證信任鏈 |

> **注意**：若路徑上有 TLS 攔截裝置（MITM），請針對 VEN ↔ PCE 流量**關閉 TLS 檢查**，否則憑證鏈不完整將導致連線失敗。

---

## 概述

使用 VEN `.rpm` 或 `.deb` 安裝包直接安裝，並手動執行啟用指令將 Agent 向 PCE 回報。

---

## 使用腳本自動安裝 (建議)

```bash
sudo bash deploy-illumio.sh
```

腳本會依序執行：偵測 OS → 檢查套件(缺件即停) → 匯入憑證 → 安裝 VEN → 啟用。

> **執行前請先編輯 `deploy-illumio.sh` 並修改以下變數**：
> - `ACTIVATION_CODE`: 您的 Activation Code
> - `MANAGEMENT_SERVER`: PCE 管理節點與 Port，例如 `pce.example.com:8443`
> - `SOURCE_DIR`: (選填) `.rpm` 或 `.deb` 安裝包所在的目錄。若留空，則會自動在腳本相同的目錄下尋找安裝包。

---

## 全手動安裝步驟

### 步驟一：檢查相依套件

#### RHEL 7 / CentOS 7
```bash
rpm -q bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed
sudo yum install -y bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed
```

#### RHEL 8+ / Rocky / AlmaLinux
```bash
rpm -q bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux
sudo dnf install -y bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux
```

#### Ubuntu / Debian
```bash
# 核心相依套件
sudo apt-get install -y dnsutils curl libgmp10 ipset iptables libcap2 libmnl0 libnfnetlink0 net-tools sed

# 其他 VEN 官方宣告相依套件 (若系統尚未安裝)
sudo apt-get install -y uuid-runtime apt-transport-https
```

### 步驟二：匯入自簽 CA 憑證

```bash
# RHEL 系列
sudo tee /etc/pki/ca-trust/source/anchors/illumio-ca.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

sudo update-ca-trust force-enable
sudo update-ca-trust extract

# Ubuntu / Debian
sudo tee /usr/local/share/ca-certificates/illumio-ca.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

sudo update-ca-certificates
```

#### 驗證憑證是否生效

```bash
# 方法 A：curl TLS 握手測試
curl -vvI https://<PCE_FQDN>:<PORT>
# 預期看到: "SSL certificate verify ok"

# 方法 B：確認 CA 已合併進系統信任庫 (RHEL 系列)
grep -i "illumio" /etc/pki/tls/certs/ca-bundle.crt
# 預期看到: "# illumioCA" 相關文字；若無輸出，請重新執行 update-ca-trust extract
```

### 步驟三：安裝 VEN

```bash
# CentOS / RHEL
sudo rpm -ivh <VEN_FILE>.rpm

# Ubuntu / Debian
sudo dpkg -i <VEN_FILE>.deb
```

### 步驟四：啟用 (手動回報)

```bash
sudo /opt/illumio_ven/illumio-ven-ctl activate \
    --management-server <PCE_FQDN>:<PORT> \
    --activation-code <ACTIVATION_CODE>
```

### 步驟五：驗證

```bash
sudo /opt/illumio_ven/illumio-ven-ctl status
```

---

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| SSL 驗證失敗 | 重新匯入憑證並 `update-ca-trust extract` |
| rpm 安裝失敗 | 先確認相依套件已安裝 |
| 啟用失敗 | 確認憑證/網路/Activation Code |

---

## 卸載（Unpair + 移除）

> **建議順序：先 Unpair → 再移除套件**

### 步驟一：解除配對 (Unpair)

```bash
sudo /opt/illumio_ven/illumio-ven-ctl unpair [recommended | saved | open]
```

| 模式 | 說明 | 安全考量 |
|------|------|----------|
| `recommended` | 解除後僅開放 SSH (port 22)，直到重新開機 | 若主機有其他服務，解除後將無法連線 |
| `saved` | 解除後還原至 VEN 安裝前的 iptables 狀態 | 舊規則可能已過期，需人工確認 |
| `open` | 解除後開放所有埠 | 高風險，僅用於隔離環境 |

### 步驟二：移除 VEN 套件

```bash
# RHEL 系列
sudo rpm -e illumio-ven

# Ubuntu / Debian
sudo dpkg --purge illumio-ven
```

### 步驟三（可選）：移除憑證

```bash
# RHEL 系列
sudo rm -f /etc/pki/ca-trust/source/anchors/illumio-ca.crt
sudo update-ca-trust extract

# Ubuntu / Debian
sudo rm -f /usr/local/share/ca-certificates/illumio-ca.crt
sudo update-ca-certificates
```

> **注意**：使用 `rpm -e` 或 `dpkg --purge` 直接移除而不先 Unpair，Illumio 官方**不建議**此做法，僅在無法執行 `illumio-ven-ctl unpair` 時使用。
