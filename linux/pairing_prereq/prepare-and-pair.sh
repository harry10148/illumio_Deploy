#!/bin/bash
###############################################################################
# Illumio VEN — 方式一前置作業：套件檢查 + 自簽憑證匯入
#
# 此腳本用於 Illumio 官方配對腳本 (pair.sh) 執行前的準備工作：
#   1. 偵測 OS 類型
#   2. 檢查相依套件 (缺件僅報告，不自動安裝)
#   3. 匯入自簽 CA 憑證 (含防重複檢查)
#
# 使用方式:
#   sudo bash prepare-and-pair.sh
#
# 注意: 需要 root 權限
###############################################################################

set -e

# ==========================================
# 顏色定義
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_ok()   { echo -e "  ${GREEN}[OK]${NC}   $1"; }
print_fail() { echo -e "  ${RED}[MISS]${NC} $1"; }
print_skip() { echo -e "  ${YELLOW}[SKIP]${NC} $1"; }
print_info() { echo -e "  ${BLUE}[INFO]${NC} $1"; }

# dpkg 需過濾 "^ii"，排除 rc（已移除但保留設定）等誤判狀態
dpkg_check() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }

# ==========================================
# 權限檢查
# ==========================================
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] 此腳本需要 root 權限。請使用 sudo 執行。${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==========================================
# Step 1: 偵測 OS 類型
# ==========================================
print_header "Step 1: 偵測作業系統類型"

OS_TYPE=""
OS_VERSION=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="$ID"
    OS_VERSION="$VERSION_ID"
elif [ -f /etc/redhat-release ]; then
    OS_TYPE="rhel"
    OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
fi

MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d. -f1)
print_info "OS: $OS_TYPE $OS_VERSION"

# ==========================================
# Step 2: 檢查相依套件
# ==========================================
print_header "Step 2: 檢查相依套件"

MISSING_PKGS=()

case "$OS_TYPE" in
    rhel|centos|rocky|almalinux|ol)
        if [ "$MAJOR_VERSION" -le 7 ]; then
            print_info "RHEL 7 / CentOS 7 套件清單"
            REQUIRED_PKGS=(bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed)
        else
            print_info "RHEL 8+ / Rocky / AlmaLinux 套件清單"
            REQUIRED_PKGS=(bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux)
        fi
        PKG_CHECK="rpm -q"
        ;;
    ubuntu|debian)
        print_info "Ubuntu / Debian 套件清單"
        REQUIRED_PKGS=(dnsutils curl libgmp10 ipset iptables libcap2 libmnl0 libnfnetlink0 net-tools sed uuid-runtime apt-transport-https)
        PKG_CHECK="dpkg_check"
        ;;
    *)
        echo -e "${RED}[ERROR] 不支援的 OS: $OS_TYPE${NC}"
        exit 1
        ;;
esac

for pkg in "${REQUIRED_PKGS[@]}"; do
    if $PKG_CHECK "$pkg" &>/dev/null; then
        print_ok "$pkg"
    else
        print_fail "$pkg (未安裝)"
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}[WARNING] 以下套件缺失:${NC}"
    for pkg in "${MISSING_PKGS[@]}"; do
        echo -e "  ${RED}• $pkg${NC}"
    done
    echo ""
    case "$OS_TYPE" in
        rhel|centos|rocky|almalinux|ol)
            if [ "$MAJOR_VERSION" -le 7 ]; then
                echo "  安裝指令: sudo yum install -y ${MISSING_PKGS[*]}"
            else
                echo "  安裝指令: sudo dnf install -y ${MISSING_PKGS[*]}"
            fi
            ;;
        ubuntu|debian)
            echo "  安裝指令: sudo apt-get install -y ${MISSING_PKGS[*]}"
            ;;
    esac
    echo ""
    echo -e "${YELLOW}建議先安裝缺失套件後再執行配對腳本。${NC}"
fi

# ==========================================
# Step 3: 匯入自簽憑證 (防重複檢查)
# ==========================================
print_header "Step 3: 匯入自簽 CA 憑證"

CERT_CONTENT=$(cat << 'CERT_EOF'
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
CERT_EOF
)

# 優先使用腳本同目錄下的 illumio-ca.crt，若有則覆蓋內嵌憑證
if [ -f "$SCRIPT_DIR/illumio-ca.crt" ]; then
    print_info "使用外部憑證: $SCRIPT_DIR/illumio-ca.crt"
    CERT_CONTENT=$(cat "$SCRIPT_DIR/illumio-ca.crt")
else
    print_info "使用腳本內嵌憑證"
fi

case "$OS_TYPE" in
    rhel|centos|rocky|almalinux|ol)
        CERT_DIR="/etc/pki/ca-trust/source/anchors"
        CERT_FILE="$CERT_DIR/illumio-ca.crt"
        UPDATE_CMD="update-ca-trust force-enable && update-ca-trust extract"
        ;;
    ubuntu|debian)
        CERT_DIR="/usr/local/share/ca-certificates"
        CERT_FILE="$CERT_DIR/illumio-ca.crt"
        UPDATE_CMD="update-ca-certificates"
        ;;
esac

if [ -f "$CERT_FILE" ]; then
    EXISTING=$(cat "$CERT_FILE")
    if [ "$EXISTING" = "$CERT_CONTENT" ]; then
        print_skip "憑證已存在且內容相同，跳過匯入。"
    else
        print_info "憑證檔案內容不同，更新中..."
        echo "$CERT_CONTENT" > "$CERT_FILE"
        chmod 644 "$CERT_FILE"
        eval "$UPDATE_CMD"
        print_ok "憑證已更新。"
    fi
else
    print_info "匯入憑證至: $CERT_FILE"
    mkdir -p "$CERT_DIR"
    echo "$CERT_CONTENT" > "$CERT_FILE"
    chmod 644 "$CERT_FILE"
    eval "$UPDATE_CMD"
    print_ok "憑證匯入成功。"
fi

# ==========================================
# 完成摘要
# ==========================================
print_header "前置作業完成"

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    echo -e "${GREEN}所有檢查通過！可以執行 Illumio 官方配對腳本。${NC}"
else
    echo -e "${YELLOW}憑證已匯入，但有 ${#MISSING_PKGS[@]} 個套件缺失。${NC}"
    echo -e "${YELLOW}建議先安裝缺失套件後再執行配對腳本。${NC}"
fi

echo ""
echo "配對腳本範例 (建議現代環境使用 --tlsv1.2；--tlsv1 僅供 RHEL 5 等老舊系統相容)："
echo '  rm -fr /opt/illumio_ven_data/tmp && umask 026 && \'
echo '  mkdir -p /opt/illumio_ven_data/tmp && \'
echo '  curl --tlsv1.2 "https://<PCE_FQDN>:<PORT>/api/v27/software/ven/image?pair_script=pair.sh&profile_id=<ID>" \'
echo '    -o /opt/illumio_ven_data/tmp/pair.sh && \'
echo '  chmod +x /opt/illumio_ven_data/tmp/pair.sh && \'
echo '  /opt/illumio_ven_data/tmp/pair.sh --management-server <PCE_FQDN>:<PORT> --activation-code <CODE>'
echo ""
