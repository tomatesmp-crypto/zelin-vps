#!/bin/bash
set -e
echo ""
echo "=========================================="
echo "  ZELIN VPS - Setup (QEMU + SSH)"
echo "  12 vCPU / 48GB RAM / 80GB Disco"
echo "=========================================="
echo ""

VM_DIR="$HOME/vms"
IMG_FILE="$VM_DIR/vps.img"
SEED_FILE="$VM_DIR/vps-seed.iso"

# --- 1. KVM ---
echo "[1/5] Verificando KVM..."
if [ -e /dev/kvm ]; then
    echo "  KVM disponible! VM rapida."
else
    echo "  Habilitando KVM..."
    sudo modprobe kvm_intel 2>/dev/null || sudo modprobe kvm_amd 2>/dev/null || true
    sudo mknod /dev/kvm c 10 232 2>/dev/null || true
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    [ -e /dev/kvm ] && echo "  KVM activado!" || echo "  Sin KVM - VM sera lenta"
fi

# --- 2. Directorio ---
echo "[2/5] Preparando disco..."
mkdir -p "$VM_DIR"

# --- 3. Descargar Ubuntu Cloud Image ---
echo "[3/5] Descargando Ubuntu Server 22.04..."
if [ -f "$IMG_FILE" ]; then
    echo "  Imagen ya existe, saltando."
else
    wget --progress=bar:force "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" -O "$IMG_FILE.tmp"
    mv "$IMG_FILE.tmp" "$IMG_FILE"
    echo "  Descarga completa!"
fi

# --- 4. Redimensionar ---
echo "[4/5] Redimensionando disco a 80G..."
qemu-img resize "$IMG_FILE" 80G 2>/dev/null || qemu-img create -f qcow2 -F qcow2 -b "$IMG_FILE" "$IMG_FILE.tmp" 80G 2>/dev/null && mv "$IMG_FILE.tmp" "$IMG_FILE" 2>/dev/null || true

# --- 5. Cloud-init ---
echo "[5/5] Configurando cloud-init..."
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
ssh_pwauth: true
packages:
  - htop
  - tmux
  - nano
  - curl
  - wget
  - git
  - build-essential
  - python3
  - python3-pip
  - nodejs
  - npm
runcmd:
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - echo "Zelin VPS listo!" > /etc/motd
UD

cat > /tmp/ci/meta-data << 'MD'
instance-id: zelin-vps
local-hostname: zelin-vps
MD

genisoimage -output "$SEED_FILE" -volid cidata -joliet -rock /tmp/ci/user-data /tmp/ci/meta-data 2>/dev/null || cloud-localds "$SEED_FILE" /tmp/ci/user-data /tmp/ci/meta-data 2>/dev/null || true
rm -rf /tmp/ci

# --- Guardar config ---
cat > "$VM_DIR/vps.conf" << 'CONF'
VM_NAME="vps"
HOSTNAME="zelin-vps"
USERNAME="zelin"
PASSWORD="zelin2026"
DISK_SIZE="80G"
MEMORY="48000"
CPUS="12"
SSH_PORT="2222"
IMG_FILE="$HOME/vms/vps.img"
SEED_FILE="$HOME/vps/vps-seed.iso"
CONF

# --- noVNC ---
echo "Instalando noVNC..."
if [ ! -d /usr/share/novnc ]; then
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq novnc websockify 2>/dev/null || {
        sudo mkdir -p /usr/share/novnc
        wget -q "https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz" -O /tmp/novnc.tar.gz 2>/dev/null && sudo tar xzf /tmp/novnc.tar.gz -C /usr/share/novnc --strip-components=1 2>/dev/null || true
    }
fi

# --- Cloudflare Tunnel ---
echo "Instalando Cloudflare Tunnel..."
[ -f /usr/local/bin/cloudflared ] || {
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cf
    sudo mv /tmp/cf /usr/local/bin/cloudflared && sudo chmod +x /usr/local/bin/cloudflared
}

# --- Keep-alive ---
cat > "$VM_DIR/keep-alive.sh" << 'KA'
#!/bin/bash
while true; do echo "alive $(date)" >> /tmp/vps-alive.log; sleep 240; done
KA
chmod +x "$VM_DIR/keep-alive.sh"

echo ""
echo "=========================================="
echo "  SETUP COMPLETADO!"
echo "=========================================="
echo "  Ejecuta: bash start.sh"
echo "=========================================="
