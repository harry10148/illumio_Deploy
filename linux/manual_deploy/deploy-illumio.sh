#!/bin/bash
###############################################################################
# Illumio VEN — 方式二：手動安裝 + 手動回報 (Linux)
#
# 功能:
#   1. 偵測 OS 類型 (RHEL 7 / RHEL 8+ / Ubuntu/Debian)
#   2. 檢查相依套件 — 缺件即停止 (不自動安裝)
#   3. 匯入自簽 CA 憑證 (含防重複檢查)
#   4. 安裝 VEN 套件 (rpm/dpkg)
#   5. 執行 activation 回報至 PCE
#
# 使用方式:
#   sudo bash deploy-illumio.sh
#
# 注意:
#   - 需要 root 權限
#   - VEN RPM/DEB 安裝包需與此腳本放在同一目錄
###############################################################################

set -e

# ==========================================
# 設定區 (請依環境修改)
# ==========================================
ACTIVATION_CODE="<YOUR_ACTIVATION_CODE>"
MANAGEMENT_SERVER="<YOUR_PCE_FQDN:PORT>"
SOURCE_DIR=""      # 留空=自動尋找腳本所在目錄，可指定絕對路徑例如 "/tmp/installers"
VEN_RPM_FILE=""    # 留空=自動偵測 SOURCE_DIR 內的 .rpm
VEN_DEB_FILE=""    # 留空=自動偵測 SOURCE_DIR 內的 .deb
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

print_header() { echo ""; echo -e "${BLUE}============================================${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}============================================${NC}"; echo ""; }
print_ok()   { echo -e "  ${GREEN}[OK]${NC}     $1"; }
print_fail() { echo -e "  ${RED}[FAIL]${NC}   $1"; }
print_skip() { echo -e "  ${YELLOW}[SKIP]${NC}   $1"; }
print_info() { echo -e "  ${BLUE}[INFO]${NC}   $1"; }
print_error(){ echo -e "  ${RED}[ERROR]${NC}  $1"; }

# 權限檢查
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] 需要 root 權限。請使用 sudo 執行。${NC}"; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# === Step 1: 偵測 OS ===
print_header "Step 1/5: 偵測作業系統"

OS_TYPE=""; OS_VERSION=""
if [ -f /etc/os-release ]; then
    . /etc/os-release; OS_TYPE="$ID"; OS_VERSION="$VERSION_ID"
elif [ -f /etc/redhat-release ]; then
    OS_TYPE="rhel"; OS_VERSION=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
fi
MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d. -f1)
print_info "OS: $OS_TYPE $OS_VERSION"

# === Step 2: 檢查相依套件 ===
print_header "Step 2/5: 檢查相依套件"

MISSING_PKGS=()
case "$OS_TYPE" in
    rhel|centos|rocky|almalinux|ol)
        if [ "$MAJOR_VERSION" -le 7 ]; then
            REQUIRED_PKGS=(bind-utils curl gmp ipset iptables libcap libmnl libnfnetlink net-tools sed)
        else
            REQUIRED_PKGS=(bind-utils diffutils curl gawk gmp gzip libcap libnfnetlink net-tools nftables sed shadow-utils tar util-linux)
        fi
        for pkg in "${REQUIRED_PKGS[@]}"; do
            if rpm -q "$pkg" &>/dev/null; then print_ok "$pkg"; else print_fail "$pkg"; MISSING_PKGS+=("$pkg"); fi
        done ;;
    ubuntu|debian)
        REQUIRED_PKGS=(dnsutils curl libgmp10 ipset iptables libcap2 libmnl0 libnfnetlink0 net-tools sed uuid-runtime apt-transport-https)
        for pkg in "${REQUIRED_PKGS[@]}"; do
            if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then print_ok "$pkg"; else print_fail "$pkg"; MISSING_PKGS+=("$pkg"); fi
        done ;;
    *) print_error "不支援的 OS: $OS_TYPE"; exit 1 ;;
esac

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo ""; print_error "以下套件缺失，腳本停止:"; echo ""
    for pkg in "${MISSING_PKGS[@]}"; do echo -e "  ${RED}• $pkg${NC}"; done; echo ""
    case "$OS_TYPE" in
        rhel|centos|rocky|almalinux|ol)
            [ "$MAJOR_VERSION" -le 7 ] && echo "  sudo yum install -y ${MISSING_PKGS[*]}" || echo "  sudo dnf install -y ${MISSING_PKGS[*]}" ;;
        ubuntu|debian) echo "  sudo apt-get install -y ${MISSING_PKGS[*]}" ;;
    esac
    echo ""; echo -e "${RED}安裝後請重新執行此腳本。${NC}"; exit 1
fi
print_ok "所有相依套件已安裝。"

# === Step 3: 匯入憑證 ===
print_header "Step 3/5: 匯入自簽 CA 憑證"

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
    rhel|centos|rocky|almalinux|ol) CERT_DIR="/etc/pki/ca-trust/source/anchors"; UPDATE_CMD="update-ca-trust force-enable && update-ca-trust extract" ;;
    ubuntu|debian) CERT_DIR="/usr/local/share/ca-certificates"; UPDATE_CMD="update-ca-certificates" ;;
esac
CERT_FILE="$CERT_DIR/illumio-ca.crt"

if [ -f "$CERT_FILE" ] && [ "$(cat "$CERT_FILE")" = "$CERT_CONTENT" ]; then
    print_skip "憑證已存在，跳過匯入。"
else
    mkdir -p "$CERT_DIR"
    echo "$CERT_CONTENT" > "$CERT_FILE"
    chmod 644 "$CERT_FILE"
    eval $UPDATE_CMD
    print_ok "憑證匯入成功。"
fi

# === Step 4: 安裝 VEN ===
print_header "Step 4/5: 安裝 VEN 套件"

# 先確認 VEN 是否已安裝，已安裝則跳過此步驟
VEN_ALREADY_INSTALLED=false
case "$OS_TYPE" in
    rhel|centos|rocky|almalinux|ol)
        rpm -q illumio-ven &>/dev/null && VEN_ALREADY_INSTALLED=true ;;
    ubuntu|debian)
        dpkg -l illumio-ven 2>/dev/null | grep -q "^ii" && VEN_ALREADY_INSTALLED=true ;;
esac

if [ "$VEN_ALREADY_INSTALLED" = true ]; then
    print_skip "VEN 已安裝，跳過安裝步驟。"
else
    [ -z "$SOURCE_DIR" ] && TARGET_DIR="$SCRIPT_DIR" || TARGET_DIR="$SOURCE_DIR"

    case "$OS_TYPE" in
        rhel|centos|rocky|almalinux|ol)
            [ -z "$VEN_RPM_FILE" ] && VEN_RPM_FILE=$(ls "$TARGET_DIR"/*.rpm 2>/dev/null | head -1) || VEN_RPM_FILE="$TARGET_DIR/$VEN_RPM_FILE"
            if [ -z "$VEN_RPM_FILE" ] || [ ! -f "$VEN_RPM_FILE" ]; then
                print_error "找不到 VEN RPM 安裝包。請確保留在: $TARGET_DIR"; exit 1
            fi
            print_info "安裝: $(basename "$VEN_RPM_FILE")"
            rpm -ivh "$VEN_RPM_FILE"
            print_ok "VEN 安裝完成。" ;;
        ubuntu|debian)
            [ -z "$VEN_DEB_FILE" ] && VEN_DEB_FILE=$(ls "$TARGET_DIR"/*.deb 2>/dev/null | head -1) || VEN_DEB_FILE="$TARGET_DIR/$VEN_DEB_FILE"
            if [ -z "$VEN_DEB_FILE" ] || [ ! -f "$VEN_DEB_FILE" ]; then
                print_error "找不到 VEN DEB 安裝包。請確保留在: $TARGET_DIR"; exit 1
            fi
            print_info "安裝: $(basename "$VEN_DEB_FILE")"
            dpkg -i "$VEN_DEB_FILE"
            print_ok "VEN 安裝完成。" ;;
    esac
fi

# === Step 5: 啟用 ===
print_header "Step 5/5: 啟用 VEN Agent"

VEN_CTL="/opt/illumio_ven/illumio-ven-ctl"
if [ ! -f "$VEN_CTL" ]; then print_error "找不到 $VEN_CTL"; exit 1; fi
if [ "$ACTIVATION_CODE" = "<YOUR_ACTIVATION_CODE>" ] || [ "$MANAGEMENT_SERVER" = "<YOUR_PCE_FQDN:PORT>" ]; then
    print_error "請先設定 ACTIVATION_CODE 和 MANAGEMENT_SERVER。"; exit 1
fi

print_info "Server: $MANAGEMENT_SERVER"
sudo "$VEN_CTL" activate --management-server "$MANAGEMENT_SERVER" --activation-code "$ACTIVATION_CODE"
print_ok "啟用指令已送出。"

print_header "部署完成"
echo -e "${GREEN}驗證: sudo $VEN_CTL status${NC}"
echo ""
