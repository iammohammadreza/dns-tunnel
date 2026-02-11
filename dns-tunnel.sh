#!/bin/bash
# mrh DNS Tunnel - Public version
# DNS Tunnel + Custom Port Forward + Status Log

# =============================
# ===== User Input ===========
# =============================

echo "=== mrh DNS Tunnel Setup ==="

# Role: server or client
echo "Choose role:"
echo "1) Server"
echo "2) Client"
read -p "Enter choice (1 or 2): " CHOICE

if [[ "$CHOICE" == "1" ]]; then
    ROLE="server"
    read -p "Enter tunnel internal IP for server (example: 10.50.50.1): " TUN_IP
    read -p "Enter tunnel domain (example: www.example.com): " DOMAIN
elif [[ "$CHOICE" == "2" ]]; then
    ROLE="client"
    read -p "Enter tunnel domain (example: www.example.com): " DOMAIN
else
    echo "Invalid choice, exiting."
    exit 1
fi

read -p "Enter tunnel password (default: niloo): " USER_PASS
PASSWORD="${USER_PASS:-niloo}"

# Ports to forward (only for client)
FORWARD_PORTS=()
if [[ "$ROLE" == "client" ]]; then
    read -p "Enter first port to forward (example: 2020): " PORT1
    read -p "Enter second port to forward (example: 11322): " PORT2
    FORWARD_PORTS=($PORT1 $PORT2)
fi

# =============================
# ===== Functions ============
# =============================

log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

setup_server() {
    log_status "Starting DNS Tunnel Server..."
    sudo ip tuntap add dev dns0 mode tun 2>/dev/null || log_status "dns0 already exists"
    sudo ip addr add $TUN_IP/24 dev dns0 2>/dev/null || true
    sudo ip link set dns0 up

    sudo iodined -f -c -P $PASSWORD -m 1200 $TUN_IP $DOMAIN &
    sleep 2

    # Check status
    if ip addr show dns0 &>/dev/null; then
        log_status "Server tun interface dns0 is up."
    else
        log_status "Failed to create dns0 interface."
    fi
}

setup_client() {
    log_status "Connecting DNS Tunnel Client..."
    sudo iodine -f -P $PASSWORD $DOMAIN &
    sleep 5

    # Setup TUN interface
    CLIENT_TUN_IP="10.50.50.2"
    sudo ip addr add $CLIENT_TUN_IP/24 dev dns0 2>/dev/null || true
    sudo ip link set dns0 up
    sudo sysctl -w net.ipv4.ip_forward=1

    # Forward ports
    for PORT in "${FORWARD_PORTS[@]}"; do
        log_status "Forwarding port $PORT..."
        sudo iptables -A INPUT -i dns0 -p tcp --dport $PORT -j ACCEPT
        sudo iptables -A INPUT -i dns0 -p udp --dport $PORT -j ACCEPT
        sudo iptables -t nat -A PREROUTING -i dns0 -p tcp --dport $PORT -j DNAT --to-destination $CLIENT_TUN_IP:$PORT
        sudo iptables -t nat -A PREROUTING -i dns0 -p udp --dport $PORT -j DNAT --to-destination $CLIENT_TUN_IP:$PORT
        sudo iptables -t nat -A POSTROUTING -o dns0 -p tcp --dport $PORT -j MASQUERADE
        sudo iptables -t nat -A POSTROUTING -o dns0 -p udp --dport $PORT -j MASQUERADE
    done

    # Status check
    if ip addr show dns0 &>/dev/null; then
        log_status "Client tun interface dns0 is up."
    else
        log_status "Failed to create dns0 interface."
    fi

    log_status "Ports forwarded: ${FORWARD_PORTS[*]}"
}

# =============================
# ===== Run ==================
# =============================

if [[ "$ROLE" == "server" ]]; then
    setup_server
elif [[ "$ROLE" == "client" ]]; then
    setup_client
fi

log_status "mrh DNS Tunnel setup complete."
