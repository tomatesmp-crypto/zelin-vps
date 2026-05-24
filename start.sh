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

# Verify QEMU
if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "ERROR: qemu-system-x86_64 no encontrado!"
    echo "Rebuildea el environment en Firebase Studio"
    exit 1
fi

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

# QEMU - build the command
QEMU_CMD="qemu-system-x86_64"
QEMU_CMD="$QEMU_CMD $KVM_FLAG"
QEMU_CMD="$QEMU_CMD -smp $CPUS"
QEMU_CMD="$QEMU_CMD -m $MEMORY"
QEMU_CMD="$QEMU_CMD -drive file=$IMG_FILE,format=qcow2"
if [ -f "$SEED_FILE" ]; then
    QEMU_CMD="$QEMU_CMD -cdrom $SEED_FILE"
fi
QEMU_CMD="$QEMU_CMD -boot c"
QEMU_CMD="$QEMU_CMD -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::5900-:5900"
QEMU_CMD="$QEMU_CMD -device virtio-net-pci,netdev=net0"
QEMU_CMD="$QEMU_CMD -vnc :0"
QEMU_CMD="$QEMU_CMD -daemonize"
QEMU_CMD="$QEMU_CMD -display none"

echo "  Ejecutando: $QEMU_CMD"
eval $QEMU_CMD

echo "  QEMU iniciado!"

# noVNC
sleep 2
pkill -f "websockify.*6080" 2>/dev/null || true
sleep 1
websockify --web "$HOME/novnc" 6080 localhost:5900 &
echo "  noVNC en puerto 6080"

# Keep-alive
pkill -f "keep-alive.sh" 2>/dev/null || true
nohup bash "$VM_DIR/keep-alive.sh" > /dev/null 2>&1 &
echo "  Keep-alive activo"

# Esperar SSH
echo ""
echo "  Esperando SSH (puede tardar 2-3 min sin KVM)..."
for i in $(seq 1 60); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes -p "$SSH_PORT" "$USERNAME@localhost" "echo ok" 2>/dev/null; then
        echo "  SSH listo!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "  TIMEOUT: SSH no respondio en 5 min"
        echo "  La VM puede seguir arrancando. Intenta manualmente:"
        echo "  ssh $USERNAME@localhost -p $SSH_PORT"
    fi
    sleep 5
    echo "  Esperando... ($((i*5))s)"
done

# Cloudflare Tunnel para SSH remoto
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
    echo "  SSH remoto: ssh $USERNAME@$TUNNEL_URL"
    echo "$TUNNEL_URL" > ~/tunnel-url.txt
else
    echo "  SSH remoto: revisa con 'cat ~/tunnel.log'"
fi
echo "  Password:   $PASSWORD"
echo "  VNC:        Puerto 6080 (preview Firebase)"
echo "  CPUs:       $CPUS vCPU"
echo "  RAM:        $((MEMORY/1024)) GB"
echo ""
echo "  Detener:    pkill -f qemu-system-x86_64"
echo "=========================================="
echo ""
