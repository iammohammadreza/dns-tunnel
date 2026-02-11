#!/bin/bash
# DNS Tunnel Auto Script
# Usage:
#   ./dns-tunnel-auto.sh

# =========================
# === Configuration =======
# =========================

# نقش خودت را انتخاب کن: server / client
ROLE=""
# اگر سرور هست، IP تونل داخلی
TUN_IP=""
# دامنه تونل
DOMAIN=""
# پسورد تونل
PASSWORD="niloo"

# =========================
# === User Input =========
# =========================

echo "DNS Tunnel Setup"
echo "انتخاب نقش:"
echo "1) Server"
echo "2) Client"
read -p "انتخاب کن (1 یا 2): " CHOICE

if [[ "$CHOICE" == "1" ]]; then
    ROLE="server"
    read -p "IP داخلی تونل برای سرور (مثلا 10.50.50.1): " TUN_IP
    read -p "دامنه تونل (مثلا t1.example.com): " DOMAIN
elif [[ "$CHOICE" == "2" ]]; then
    ROLE="client"
    read -p "دامنه تونل (مثلا t1.example.com): " DOMAIN
else
    echo "انتخاب نامعتبر"
    exit 1
fi

read -p "پسورد تونل (پیش فرض: niloo): " USER_PASS
if [[ ! -z "$USER_PASS" ]]; then
    PASSWORD="$USER_PASS"
fi

# =========================
# === Functions ==========
# =========================

setup_server() {
    echo "[*] Setting up DNS Tunnel Server..."
    # TUN Interface
    sudo ip tuntap add dev dns0 mode tun 2>/dev/null || echo "[*] dns0 exists"
    sudo ip addr add $TUN_IP/24 dev dns0 2>/dev/null || true
    sudo ip link set dns0 up

    # Open UDP port 53
    sudo ufw allow 53/udp >/dev/null 2>&1 || true

    # Start iodine server
    echo "[*] Starting iodined..."
    sudo iodined -f -c -P $PASSWORD -m 1200 $TUN_IP $DOMAIN
}

setup_client() {
    echo "[*] Connecting DNS Tunnel Client..."
    sudo iodine -f -P $PASSWORD $DOMAIN
}

# =========================
# === Run ================
# =========================

if [[ "$ROLE" == "server" ]]; then
    setup_server
elif [[ "$ROLE" == "client" ]]; then
    setup_client
fi
