#!/bin/bash
set -e
echo ""
echo "=========================================="
echo "  ZELIN VPS - Setup (QEMU + SSH)"
echo "=========================================="
echo ""

VM_DIR="$HOME/vms"
IMG_FILE="$VM_DIR/vps.img"
SEED_FILE="$VM_DIR/vps-seed.iso"

# --- Verify QEMU ---
echo "[0/5] Verificando paquetes..."
if command -v qemu-system-x86_64 &>/dev/null; then
    echo "  QEMU OK"
else
    echo "  ERROR: qemu-system-x86_64 no encontrado!"
    echo "  Edita dev.nix y agrega pkgs.qemu, luego rebuildea"
    exit 1
fi

# --- 1. KVM ---
echo "[1/5] Verificando KVM..."
if [ -e /dev/kvm ]; then
    echo "  KVM disponible!"
else
    sudo modprobe kvm_intel 2>/dev/null || sudo modprobe kvm_amd 2>/dev/null || true
    sudo mknod /dev/kvm c 10 232 2>/dev/null || true
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    [ -e /dev/kvm ] && echo "  KVM activado!" || echo "  Sin KVM - VM lenta"
fi

# --- 2. Directorio ---
echo "[2/5] Preparando disco..."
mkdir -p "$VM_DIR"

# --- 3. Descargar Ubuntu ---
echo "[3/5] Descargando Ubuntu 22.04..."
if [ -f "$IMG_FILE" ]; then
    echo "  Imagen ya existe."
else
    wget --progress=bar:force "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" -O "$IMG_FILE.tmp"
    mv "$IMG_FILE.tmp" "$IMG_FILE"
    echo "  Descarga completa!"
fi

# --- 4. Redimensionar ---
echo "[4/5] Redimensionando a 80G..."
qemu-img resize "$IMG_FILE" 80G

# --- 5. Cloud-init ---
echo "[5/5] Cloud-init..."
mkdir -p /tmp/ci

cat > /tmp/ci/user-data << 'UD'
#cloud-config
hostname: zelin-vps
manage_etc_hosts: true
users:
  - name: zelin
    plain_text_passwd: zelin2026
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys: []
ssh_pwauth: true
chpasswd:
  expire: false
packages:
  - htop
  - tmux
  - nano
  - curl
  - wget
  - git
  - build-essential
  - python3
  - nodejs
  - npm
runcmd:
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - echo "Zelin VPS listo!" > /etc/motd
UD

cat > /tmp/ci/meta-data << 'MD'
instance-id: zelin-vps-001
local-hostname: zelin-vps
MD

if command -v mkisofs &>/dev/null; then
    mkisofs -output "$SEED_FILE" -volid cidata -joliet -rock /tmp/ci/user-data /tmp/ci/meta-data 2>/dev/null
elif command -v genisoimage &>/dev/null; then
    genisoimage -output "$SEED_FILE" -volid cidata -joliet -rock /tmp/ci/user-data /tmp/ci/meta-data 2>/dev/null
else
    echo "  WARNING: no se pudo crear ISO cloud-init"
fi
rm -rf /tmp/ci

# --- noVNC ---
echo "Configurando noVNC..."
if [ ! -d "$HOME/novnc" ]; then
    mkdir -p "$HOME/novnc"
    wget -q "https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz" -O /tmp/novnc.tar.gz
    tar xzf /tmp/novnc.tar.gz -C "$HOME/novnc" --strip-components=1
fi

# --- Cloudflare Tunnel ---
echo "Instalando Cloudflare Tunnel..."
if [ ! -f "$HOME/bin/cloudflared" ]; then
    mkdir -p "$HOME/bin"
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$HOME/bin/cloudflared"
    chmod +x "$HOME/bin/cloudflared"
fi

echo ""
echo "=========================================="
echo "  SETUP COMPLETADO! Ejecuta: bash start.sh"
echo "=========================================="
