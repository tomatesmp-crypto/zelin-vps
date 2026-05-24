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

# --- Verify QEMU exists ---
echo "[0/5] Verificando paquetes Nix..."
if command -v qemu-system-x86_64 &>/dev/null; then
    echo "  QEMU OK: $(qemu-system-x86_64 --version 2>&1 | head -1)"
else
    echo "  ERROR: qemu-system-x86_64 no encontrado!"
    echo "  Rebuildea el environment para que dev.nix instale QEMU"
    exit 1
fi

if command -v mkisofs &>/dev/null; then
    echo "  cdrtools OK"
else
    echo "  WARNING: mkisofs no encontrado, cloud-init puede fallar"
fi

# --- 1. KVM ---
echo "[1/5] Verificando KVM..."
if [ -e /dev/kvm ]; then
    echo "  KVM disponible! VM rapida."
else
    echo "  Habilitando KVM..."
    sudo modprobe kvm_intel 2>/dev/null || sudo modprobe kvm_amd 2>/dev/null || true
    sudo mknod /dev/kvm c 10 232 2>/dev/null || true
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    if [ -e /dev/kvm ]; then
        echo "  KVM activado!"
    else
        echo "  Sin KVM - VM sera lenta pero funcional"
    fi
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
qemu-img resize "$IMG_FILE" 80G

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

# Use mkisofs from cdrtools (Nix package)
if command -v mkisofs &>/dev/null; then
    mkisofs -output "$SEED_FILE" -volid cidata -joliet -rock /tmp/ci/user-data /tmp/ci/meta-data
elif command -v genisoimage &>/dev/null; then
    genisoimage -output "$SEED_FILE" -volid cidata -joliet -rock /tmp/ci/user-data /tmp/ci/meta-data
elif command -v cloud-localds &>/dev/null; then
    cloud-localds "$SEED_FILE" /tmp/ci/user-data /tmp/ci/meta-data
else
    echo "  WARNING: No se pudo crear ISO de cloud-init"
    echo "  La VM arrancara pero sin usuario zelin preconfigurado"
fi
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
SEED_FILE="$HOME/vms/vps-seed.iso"
CONF

# --- noVNC ---
echo "Configurando noVNC..."
if [ ! -d "$HOME/novnc" ]; then
    mkdir -p "$HOME/novnc"
    wget -q "https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz" -O /tmp/novnc.tar.gz
    tar xzf /tmp/novnc.tar.gz -C "$HOME/novnc" --strip-components=1
    echo "  noVNC instalado en ~/novnc"
else
    echo "  noVNC ya existe"
fi

# --- Cloudflare Tunnel ---
echo "Instalando Cloudflare Tunnel..."
if [ ! -f "$HOME/bin/cloudflared" ]; then
    mkdir -p "$HOME/bin"
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$HOME/bin/cloudflared"
    chmod +x "$HOME/bin/cloudflared"
    echo "  cloudflared instalado en ~/bin"
else
    echo "  cloudflared ya existe"
fi

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
