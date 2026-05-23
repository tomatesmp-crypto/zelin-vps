#!/bin/bash
set -e

VM_DIR="$HOME/vms"
IMG_FILE="$VM_DIR/vps.img"
SEED_FILE="$VM_DIR/vps-seed.iso"
SSH_PORT="2222"
MEMORY="48000"
CPUS="12"
USERNAME="zelin"
PASSWORD="zelin2026"

# Ya corriendo?
if pgrep -f "qemu-system-x86_64.*$IMG_FILE" > /dev/null 2>&1; then
    echo "VM ya corriendo!"
    echo "  SSH: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "  Pass: $PASSWORD"
    exit 0
fi

echo ""
echo "Iniciando VPS (${CPUS}vCPU / $((MEMORY/1024))GB RAM)..."
echo ""

# KVM
KVM_FLAG=""
[ -e /dev/kvm ] && KVM_FLAG="-enable-kvm"

# QEMU
qemu-system-x86_64 \
    $KVM_FLAG \
    -smp "$CPUS" \
    -m "$MEMORY" \
    -drive file="$IMG_FILE",format=qcow2 \
    ${SEED_FILE:+-cdrom "$SEED_FILE"} \
    -boot c \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::5900-:5900 \
    -device virtio-net-pci,netdev=net0 \
    -vnc :0 \
    -daemonize \
    -display none

echo "  QEMU iniciado!"

# noVNC
sleep 2
pkill -f "websockify.*6080" 2>/dev/null || true
sleep 1
websockify --web /usr/share/novnc/ 6080 localhost:5900 &
echo "  noVNC en puerto 6080"

# Keep-alive
pkill -f "keep-alive.sh" 2>/dev/null || true
nohup bash "$VM_DIR/keep-alive.sh" > /dev/null 2>&1 &
echo "  Keep-alive activo"

# Esperar SSH
echo ""
echo "  Esperando SSH..."
for i in $(seq 1 30); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes -p "$SSH_PORT" "$USERNAME@localhost" "echo ok" 2>/dev/null; then
        echo "  SSH listo!"
        break
    fi
    sleep 5
    echo "  Esperando... ($((i*5))s)"
done

# Cloudflare Tunnel para SSH remoto
echo ""
echo "  Creando tunnel SSH publico..."
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1
nohup cloudflared tunnel --url ssh://localhost:$SSH_PORT > ~/tunnel.log 2>&1 &
sleep 10
TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/tunnel.log 2>/dev/null | head -1)

echo ""
echo "=========================================="
echo "  VPS INICIADO!"
echo "=========================================="
echo ""
echo "  SSH local:  ssh $USERNAME@localhost -p $SSH_PORT"
echo "  SSH remoto: ssh $USERNAME@$TUNNEL_URL"
echo "  Password:   $PASSWORD"
echo "  VNC:        Puerto 6080 (preview Firebase)"
echo "  CPUs:       $CPUS vCPU"
echo "  RAM:        $((MEMORY/1024)) GB"
echo ""

if [ -n "$TUNNEL_URL" ]; then
    echo "$TUNNEL_URL" > ~/tunnel-url.txt
else
    echo "  Tunnel: revisa con 'cat ~/tunnel.log'"
fi

echo "  Detener:    pkill -f qemu-system-x86_64"
echo "=========================================="
echo ""
