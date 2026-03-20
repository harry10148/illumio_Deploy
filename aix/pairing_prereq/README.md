# Illumio VEN — 官方配對前置作業 (AIX)

> 適用於：AIX 7.1 / 7.2 / 7.3  
> 最後更新：2026-03-05

---

## 概述

此方式使用 Illumio 官方提供的 AIX 配對腳本 (`pair.aix.sh`)，從 PCE 自動下載並完成 VEN 安裝與啟用。

**執行前必須：**
1. 確認 IPFilter 已正確安裝（參考 [方式二 AIX 手冊](../manual_deploy/README.md) 步驟一~二）
2. 匯入自簽 CA 憑證（否則 `curl` 下載時會 SSL 驗證失敗）

---

## 步驟一：匯入 CA 憑證

AIX 使用 `/var/ssl/certs/ca-bundle.crt` 作為信任憑證庫。

### 全新環境

```bash
mkdir -p /var/ssl/certs

cat > /var/ssl/certs/ca-bundle.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

chmod 644 /var/ssl/certs/ca-bundle.crt
```

### 已有 ca-bundle.crt 時（追加方式）

> 若系統已有其他信任憑證在 `ca-bundle.crt` 中，請使用追加方式避免覆蓋：

```bash
cat >> /var/ssl/certs/ca-bundle.crt << 'EOF'

-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF

chmod 644 /var/ssl/certs/ca-bundle.crt
```

### 驗證

```bash
openssl s_client -connect <PCE_FQDN>:8443 \
    -CAfile /var/ssl/certs/ca-bundle.crt \
    -servername <PCE_FQDN>
# 預期: Verify return code: 0 (ok)
```

---

## 步驟二：執行官方配對腳本

確認憑證已匯入且 IPFilter 已安裝後，執行 Illumio PCE 提供的 AIX 配對指令：

```bash
rm -fr /opt/illumio_ven/tmp && \
umask 026 && \
mkdir -p /opt/illumio_ven/tmp && \
curl --tlsv1 "https://<PCE_FQDN>:<PORT>/api/v27/software/ven/image?pair_script=pair.aix.sh&profile_id=<PROFILE_ID>" \
  -o /opt/illumio_ven/tmp/pair.sh && \
chmod +x /opt/illumio_ven/tmp/pair.sh && \
/opt/illumio_ven/tmp/pair.sh \
  --management-server <PCE_FQDN>:<PORT> \
  --activation-code <ACTIVATION_CODE>
```

> 請將 `<PCE_FQDN>:<PORT>`、`<PROFILE_ID>`、`<ACTIVATION_CODE>` 替換為實際值。

---

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| `curl` SSL 驗證失敗 | 憑證未匯入或內容不完整，請重新執行步驟一 |
| 配對腳本下載失敗 | 確認 DNS 可解析 PCE FQDN，防火牆允許 TCP 8443 出站 |
| VEN 啟用失敗 | 確認 IPFilter 已安裝 Illumio 版，檢查 `/opt/illumio_ven/log/` |
| IPFilter 相關問題 | 參考 [方式二 AIX 手冊](../manual_deploy/README.md) 步驟一~二 |
