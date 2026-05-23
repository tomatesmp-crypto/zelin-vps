#!/bin/bash
# ============================================
# ZELIN VPS - Comando UNICO para Firebase Studio
# Template Flutter = 16vCPU / 64GB RAM
#
# PEGA ESTO en la terminal de Firebase Studio:
# bash <(curl -fsSL https://raw.githubusercontent.com/TomatitoToho/zelin-vps/main/install.sh)
#
# Si no tienes el repo, usa los comandos individuales de abajo
# ============================================

set -e
echo ""; echo "=== ZELIN VPS - Setup ==="; echo ""

# 1. SSH
echo "[1/5] SSH..."
sudo apt-get update -qq 2>/dev/null
sudo apt-get install -y -qq openssh-server 2>/dev/null || true
sudo mkdir -p /run/sshd
id zelin &>/dev/null || sudo useradd -m -s /bin/bash zelin
echo "zelin:zelin2026" | sudo chpasswd
sudo usermod -aG sudo zelin 2>/dev/null || true
echo "root:zelin2026" | sudo chpasswd 2>/dev/null || true
sudo service ssh start 2>/dev/null || sudo /usr/sbin/sshd 2>/dev/null || true
echo "OK - ssh zelin@localhost (pass: zelin2026)"

# 2. Herramientas
echo "[2/5] Herramientas..."
sudo apt-get install -y -qq build-essential python3-pip tmux htop nano wget curl git net-tools jq 2>/dev/null || true

# 3. Node.js
echo "[3/5] Node.js..."
command -v node &>/dev/null || { curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>/dev/null && sudo apt-get install -y -qq nodejs 2>/dev/null; }
echo "Node: $(node -v 2>/dev/null || echo '?') npm: $(npm -v 2>/dev/null || echo '?')"

# 4. Cloudflare Tunnel
echo "[4/5] Cloudflare Tunnel..."
[ -f /usr/local/bin/cloudflared ] || { curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cf && sudo mv /tmp/cf /usr/local/bin/cloudflared && sudo chmod +x /usr/local/bin/cloudflared; }

# 5. Keep-alive + Tunnel + Start script
echo "[5/5] Scripts..."
nohup bash -c 'while true; do curl -s -o /dev/null https://www.google.com 2>/dev/null; sleep 240; done' > /dev/null 2>&1 &
nohup cloudflared tunnel --url ssh://localhost:22 > ~/tunnel.log 2>&1 &
sleep 8
URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/tunnel.log 2>/dev/null | head -1)

echo ""; echo "=========================================="
echo "  VPS LISTO!"
echo "=========================================="
echo "  SSH local:  ssh zelin@localhost"
echo "  Password:   zelin2026"
if [ -n "$URL" ]; then
    echo "$URL" > ~/tunnel-url.txt
    echo "  SSH remoto: ssh zelin@$URL"
else
    echo "  Tunnel: cat ~/tunnel.log (puede tardar 10s)"
fi
echo "=========================================="; echo ""
