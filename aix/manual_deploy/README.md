# Illumio VEN — 完整手動部署 (AIX)

> 適用於：AIX 7.1 / 7.2 / 7.3  
> 最後更新：2026-03-05

---

## 事前準備

| 項目 | 說明 |
|------|------|
| **權限** | root |
| **安裝包** | VEN installp 格式 (`illumio-ven`) + IPFilter (`ipfl`) |
| **CA 憑證** | PCE 自簽 CA 憑證 (PEM 格式) |
| **啟用碼** | PCE 配發的 Activation Code |
| **PCE 位址** | 例如 `pce.example.com:8443` |

---

## 步驟一：檢查 IPFilter

```bash
lslpp -l | grep -i ipfl        # 檢查 IPFilter 套件
emgr -l                        # 檢查 Emergency Fix
/usr/lib/methods/cfg_ipf -l    # 32-bit IPFilter 狀態
/lib/methods/cfg_ipf64 -l      # 64-bit IPFilter 狀態
```

| 情況 | 動作 |
|------|------|
| 無 IPFilter | 直接步驟二 |
| 有非 Illumio 版 | 先移除再步驟二 |
| 有 Illumio 版 | 跳至步驟三 |

### 移除非 Illumio 版 IPFilter (如需)

```bash
/lib/methods/cfg_ipf -u
/lib/methods/cfg_ipf64 -u
installp -u ipfl.rte
```

---

## 步驟二：安裝 Illumio 版 IPFilter

```bash
cd /tmp
inutoc . && installp -acYd . ipfl
```

---

## 步驟三：匯入 CA 憑證

```bash
# 全新
mkdir -p /var/ssl/certs
cat > /var/ssl/certs/ca-bundle.crt << 'EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF
chmod 644 /var/ssl/certs/ca-bundle.crt

# 已有 ca-bundle.crt → 追加
cat >> /var/ssl/certs/ca-bundle.crt << 'EOF'

-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
EOF
```

### 驗證

```bash
openssl s_client -connect <PCE_FQDN>:8443 \
    -CAfile /var/ssl/certs/ca-bundle.crt -servername <PCE_FQDN>
# 預期: Verify return code: 0 (ok)
```

---

## 步驟四：安裝 VEN

```bash
cd /tmp
inutoc . && installp -acXgd . illumio-ven

# 驗證
lslpp -L | grep -i illumio
```

---

## 步驟五：啟用 VEN

```bash
cd /opt/illumio_ven
perl -pi -e "s/{pce_fqdn_value}/<PCE_FQDN>/g" runtime_env.yml
perl -pi -e "s/{pce_port_value}/8443/g" runtime_env.yml

./illumio-ven-ctl activate \
    --activation-code <ACTIVATION_CODE> \
    --management-server <PCE_FQDN>:8443

# 驗證
/opt/illumio_ven/illumio-ven-ctl status
```

---

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| openssl 驗證失敗 | 確認 ca-bundle.crt 包含完整憑證鏈 |
| installp 報錯 | 確認映像檔在當前目錄，已執行 `inutoc .` |
| perl 不存在 | 改用 `sed -i "s/{pce_fqdn_value}/<PCE>/g" runtime_env.yml` |
| 啟用失敗 | 檢查 `/opt/illumio_ven/log/` 日誌 + TLS 測試 |

---

## 附錄：卸載

> 建議順序：**先 unpair → 再移除套件 → 視需要移除 IPFilter**

### 步驟一：以官方工具解除配對

```bash
# 確認 VEN 狀態
/opt/illumio_ven/illumio-ven-ctl status

# 選擇一種 unpair 模式:
#   open        - 解除後流量完全開放 (需自行建立防火牆規則)
#   recommended - 解除後僅允許 SSH/22，直到重新啟動
#   saved       - 解除後還原至 VEN 安裝前的 iptables 狀態
/opt/illumio_ven/illumio-ven-ctl unpair open
```

### 步驟二：移除 VEN 套件

```bash
installp -u illumio-ven

# 確認已移除
lslpp -L | egrep -i 'illu|ipf'
```

### 步驟三：移除 IPFilter（視需要）

```bash
installp -u ipfl.rte          # 移除主套件
installp -u ipfl.man.en_US    # 移除說明文件包 (可選)

# 確認
lslpp -L | egrep -i ipf
```
