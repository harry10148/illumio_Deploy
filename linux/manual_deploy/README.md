# Illumio VEN — 完整手動部署 (Linux)

> 適用於：RHEL 7/8/9、CentOS 7、Rocky Linux、AlmaLinux、Ubuntu、Debian  
> 最後更新：2026-03-05

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
