# Zelin VPS - Firebase Studio

VPS automatico en Firebase Studio con QEMU. **16 vCPU / 64 GB RAM** gratis.

## Crear workspace

Ir a: `https://studio.firebase.google.com/import?url=https://github.com/tomatesmp-crypto/zelin-vps`

1. Elegir template **Flutter** (para 16vCPU/64GB RAM)
2. Click **Create**
3. Esperar a que Nix instale los paquetes (QEMU, cdrtools, etc.)
4. En la terminal ejecutar:

```bash
cd ~/zelin-vps && bash setup.sh && bash start.sh
```

## SSH

```bash
ssh zelin@localhost -p 2222
# Password: zelin2026
```

Se crea un Cloudflare Tunnel automaticamente para SSH remoto.

## Specs

- OS: Ubuntu Server 22.04 LTS (QEMU/KVM)
- CPU: 12 vCPU (16 total)
- RAM: 46 GB (64 total)  
- Disco: 80 GB
- SSH: puerto 2222 + Cloudflare Tunnel
- VNC: puerto 6080
