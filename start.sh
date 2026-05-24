#!/bin/bash

VM_DIR="$HOME/vms"
IMG_FILE="$VM_DIR/vps.img"
SEED_FILE="$VM_DIR/vps-seed.iso"
SSH_PORT="2222"
MEMORY="48000"
CPUS="12"
USERNAME="zelin"
PASSWORD="zelin2026"

# Verify QEMU
if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "ERROR: QEMU no instalado. Rebuildea el environment."
    exit 1
fi

# Already running?
if pgrep -f "qemu-system-x86_64.*vps.img" > /dev/null 2>&1; then
    echo "VM ya corriendo!"
    echo "  SSH: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "  Pass: $PASSWORD"
    exit 0
fi

echo ""
echo "Iniciando VPS (${CPUS}vCPU / 46GB RAM)..."
echo ""

# KVM
KVM_FLAG=""
[ -e /dev/kvm ] && KVM_FLAG="-enable-kvm" && echo "  Con KVM (rapido)" || echo "  Sin KVM (lento)"

# Start QEMU
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
websockify --web "$HOME/novnc" 6080 localhost:5900 &
echo "  noVNC en puerto 6080"

# Keep-alive (simple, sin log infinito)
pkill -f "vps-keepalive" 2>/dev/null || true
(while true; do sleep 300; echo "keepalive $(date)" > /dev/null; done) &
echo "  Keep-alive activo"

# Wait for SSH (up to 10 min for non-KVM)
echo ""
echo "  Esperando SSH..."
CONNECTED=0
for i in $(seq 1 120); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -p "$SSH_PORT" "$USERNAME@localhost" "echo ok" 2>/dev/null; then
        echo "  SSH listo! (${i}x5s = $((i*5))s)"
        CONNECTED=1
        break
    fi
    # Only print every 30 seconds
    [ $((i % 6)) -eq 0 ] && echo "  Esperando... ($((i*5))s)"
    sleep 5
done

if [ $CONNECTED -eq 0 ]; then
    echo "  SSH no respondio en 10 min, pero la VM puede seguir arrancando"
    echo "  Intenta mas tarde: ssh $USERNAME@localhost -p $SSH_PORT"
fi

# Cloudflare Tunnel
echo ""
echo "  Creando tunnel SSH publico..."
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1
nohup "$HOME/bin/cloudflared" tunnel --url ssh://localhost:$SSH_PORT > ~/tunnel.log 2>&1 &
sleep 15
TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/tunnel.log 2>/dev/null | head -1)

echo ""
echo "=========================================="
echo "  VPS INICIADO!"
echo "=========================================="
echo ""
echo "  SSH local:  ssh $USERNAME@localhost -p $SSH_PORT"
if [ -n "$TUNNEL_URL" ]; then
    TUNNEL_HOST=$(echo "$TUNNEL_URL" | sed 's|https://||')
    echo "  SSH remoto: ssh $USERNAME@$TUNNEL_HOST"
    echo "$TUNNEL_HOST" > ~/tunnel-url.txt
else
    echo "  SSH remoto: revisa con 'cat ~/tunnel.log'"
fi
echo "  Password:   $PASSWORD"
echo "  VNC:        Puerto 6080 (preview Firebase)"
echo ""
echo "  Detener:    pkill -f qemu-system-x86_64"
echo "=========================================="
echo ""
