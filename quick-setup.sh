#!/bin/bash
# ============================================
# ZELIN VPS - One-Command Setup
# Pega ESTO en la terminal de Firebase Studio
# (Template Flutter = 16vCPU / 64GB RAM)
# ============================================

set -e

echo ""; echo "=========================================="; echo "  ZELIN VPS - Firebase Studio Setup"; echo "=========================================="; echo ""

# 1. Info del sistema
CPUS=$(nproc)
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo "CPUs: $CPUS | RAM: ${RAM_GB}GB"
if [ "$CPUS" -lt 8 ]; then echo "!!! NECESITAS TEMPLATE FLUTTER PARA 16vCPU/64GB !!!"; fi

# 2. SSH
echo ""; echo "[1/5] Configurando SSH..."
sudo apt-get update -qq 2>/dev/null
sudo apt-get install -y -qq openssh-server 2>/dev/null || true
sudo mkdir -p /run/sshd /etc/ssh/sshd_config.d
echo "Port 22
PermitRootLogin yes
PasswordAuthentication yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server" | sudo tee /etc/ssh/sshd_config.d/custom.conf > /dev/null
id zelin &>/dev/null || (sudo useradd -m -s /bin/bash zelin && echo "zelin:zelin2026" | sudo chpasswd && sudo usermod -aG sudo zelin)
echo "root:zelin2026" | sudo chpasswd 2>/dev/null || true
sudo service ssh start 2>/dev/null || sudo /usr/sbin/sshd 2>/dev/null || true
echo "SSH OK - User: zelin / Pass: zelin2026"

# 3. Herramientas
echo ""; echo "[2/5] Instalando herramientas..."
sudo apt-get install -y -qq build-essential python3-pip tmux htop nano wget curl git net-tools jq 2>/dev/null || true

# 4. Node.js
echo ""; echo "[3/5] Node.js..."
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>/dev/null
    sudo apt-get install -y -qq nodejs 2>/dev/null
fi
echo "Node: $(node -v 2>/dev/null || echo 'pendiente') | npm: $(npm -v 2>/dev/null || echo 'pendiente')"

# 5. Cloudflare Tunnel
echo ""; echo "[4/5] Cloudflare Tunnel..."
if [ ! -f /usr/local/bin/cloudflared ]; then
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
    sudo mv /tmp/cloudflared /usr/local/bin/cloudflared && sudo chmod +x /usr/local/bin/cloudflared
fi
echo "Cloudflared: $(which cloudflared 2>/dev/null || echo 'pendiente')"

# 6. Keep-alive
echo ""; echo "[5/5] Keep-alive + scripts..."
echo '#!/bin/bash
while true; do echo "alive $(date)" >> /tmp/vps-alive.log; curl -s -o /dev/null https://www.google.com 2>/dev/null || true; sleep 240; done' > ~/keep-alive.sh && chmod +x ~/keep-alive.sh

echo '#!/bin/bash
echo "Iniciando ZELIN VPS..."
pgrep -x sshd > /dev/null || (sudo service ssh start 2>/dev/null || sudo /usr/sbin/sshd 2>/dev/null || true)
pgrep -f keep-alive > /dev/null || nohup bash ~/keep-alive.sh > /dev/null 2>&1 &
pgrep -f "cloudflared tunnel" > /dev/null || (nohup cloudflared tunnel --url ssh://localhost:22 > ~/tunnel.log 2>&1 & sleep 8 && grep -o "https://[a-z0-9-]*\.trycloudflare\.com" ~/tunnel.log | head -1 > ~/tunnel-url.txt)
[ -f ~/tunnel-url.txt ] && echo "SSH Remoto: ssh zelin@$(cat ~/tunnel-url.txt)" || echo "Tunnel iniciando... revisa ~/tunnel.log"' > ~/start.sh && chmod +x ~/start.sh

echo '#!/bin/bash
echo "CPUs: $(nproc) | RAM: $(free -h | awk "/^Mem:/{print \$2}") | Libre: $(df -h / | tail -1 | awk "{print \$4}")"
echo "SSH: ssh zelin@localhost | Pass: zelin2026"
[ -f ~/tunnel-url.txt ] && echo "Remoto: ssh zelin@$(cat ~/tunnel-url.txt)"' > ~/vps-info.sh && chmod +x ~/vps-info.sh

# Iniciar servicios
nohup bash ~/keep-alive.sh > /dev/null 2>&1 &
nohup cloudflared tunnel --url ssh://localhost:22 > ~/tunnel.log 2>&1 &
sleep 8
TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/tunnel.log 2>/dev/null | head -1)

echo ""; echo "=========================================="
echo "  VPS LISTO!"
echo "=========================================="
echo "  User: zelin | Pass: zelin2026"
echo "  SSH local: ssh zelin@localhost"
if [ -n "$TUNNEL_URL" ]; then
    echo "$TUNNEL_URL" > ~/tunnel-url.txt
    echo "  SSH remoto: ssh zelin@$TUNNEL_URL"
else
    echo "  Tunnel: revisa con 'cat ~/tunnel.log'"
    echo "  O ejecuta: bash ~/ssh-tunnel.sh"
fi
echo "  Comandos: ~/start.sh | ~/vps-info.sh"
echo "=========================================="; echo ""
