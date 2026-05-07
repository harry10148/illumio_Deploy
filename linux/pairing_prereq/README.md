# Illumio VEN — 官方配對前置作業 (Linux)

> 適用於：RHEL 7/8/9、CentOS 7、Rocky Linux、AlmaLinux、Ubuntu、Debian  
> 最後更新：2026-04-24

---

## 概述

此方式使用 Illumio 官方配對腳本 (`pair.sh`)，從 PCE 自動下載並安裝 VEN。

**執行前必須：**
1. 確認相依套件已安裝
2. 匯入自簽 CA 憑證（否則 `curl` 下載時會 SSL 驗證失敗）

---

## 步驟一：使用腳本自動準備 (建議)

```bash
sudo bash prepare-and-pair.sh
```

此腳本會自動完成：
- 偵測 OS 類型
- 檢查相依套件（缺件僅報告，不自動安裝）
- 匯入自簽 CA 憑證（含防重複檢查）

> **憑證來源優先序**：
> 1. 同目錄下的 `illumio-ca.crt` 檔（**建議**，無需修改腳本）
> 2. 腳本內嵌憑證（編輯 `prepare-and-pair.sh` 中 `CERT_EOF` 區塊）

---

## 步驟二（手動方式）：檢查相依套件

### RHEL 7 / CentOS 7

```bash
rpm -q bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed
# 缺少時:
sudo yum install -y bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed
```

### RHEL 8/9 / Rocky / AlmaLinux

```bash
rpm -q bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux
# 缺少時:
sudo dnf install -y bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux
```

### Ubuntu / Debian

```bash
dpkg -l dnsutils curl libgmp10 ipset iptables libcap2 libmnl0 libnfnetlink0 net-tools sed uuid-runtime apt-transport-https
# 缺少時:
sudo apt-get install -y dnsutils curl libgmp10 ipset iptables libcap2 libmnl0 libnfnetlink0 net-tools sed uuid-runtime apt-transport-https
```

---

## 步驟三（手動方式）：匯入自簽 CA 憑證

### RHEL 系列

```bash
sudo tee /etc/pki/ca-trust/source/anchors/illumio-ca.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

sudo update-ca-trust force-enable
sudo update-ca-trust extract
```

### Ubuntu / Debian

```bash
sudo tee /usr/local/share/ca-certificates/illumio-ca.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

sudo update-ca-certificates
```

### 驗證

```bash
# 方法 A：curl TLS 握手測試 (建議)
curl -vvI https://<PCE_FQDN>:<PORT>
# 預期看到: "SSL certificate verify ok"
# 若出現 "curl: (60) SSL certificate problem" 代表憑證未正確匯入

# 方法 B：確認 CA 已合併進系統信任庫 (RHEL 系列)
grep -i "illumio" /etc/pki/tls/certs/ca-bundle.crt
# 預期看到: "# illumioCA" 或相關文字
# 若無輸出，請重新執行 update-ca-trust extract
```

---

## 步驟四：執行官方配對腳本

> **關於 `curl --tlsv1`**：Illumio 官方腳本範例保留 `--tlsv1` 是為了相容 RHEL 5 等老舊系統（其 OpenSSL 不支援 TLS 1.2）。**現代環境（RHEL 7+ / Ubuntu 16.04+）建議改用 `--tlsv1.2`** 以避免協商到不安全版本（PCE 端最低支援 TLS 1.2）。

```bash
rm -fr /opt/illumio_ven_data/tmp && \
umask 026 && \
mkdir -p /opt/illumio_ven_data/tmp && \
curl --tlsv1.2 "https://<PCE_FQDN>:<PORT>/api/v27/software/ven/image?pair_script=pair.sh&profile_id=<ID>" \
  -o /opt/illumio_ven_data/tmp/pair.sh && \
chmod +x /opt/illumio_ven_data/tmp/pair.sh && \
/opt/illumio_ven_data/tmp/pair.sh \
  --management-server <PCE_FQDN>:<PORT> \
  --activation-code <ACTIVATION_CODE>
```

---

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| `curl: (60) SSL certificate problem` | 憑證未匯入，重新執行步驟三 |
| `update-ca-trust` 不存在 | `yum install -y ca-certificates` |
| 配對腳本下載失敗 | 確認可連線至 PCE、DNS 解析正常 |

---

## 卸載

若日後需要移除 VEN，請參閱 [完整手動部署手冊的卸載章節](../manual_deploy/README.md#卸載unpair--移除)，依序執行 Unpair → 移除套件。
