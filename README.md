# Zelin VPS - Firebase Studio

VPS automatico en Firebase Studio con QEMU. **16 vCPU / 64 GB RAM** gratis.

## Paso a Paso

### 1. Crear workspace
Ir a: `https://studio.firebase.google.com/import?url=https://github.com/tomatesmp-crypto/zelin-vps`
- Elegir template **Flutter** (para 16vCPU/64GB RAM)
- Click **Create**

### 2. Esperar el build
- Firebase Studio va a instalar los paquetes Nix (QEMU, etc.)
- Esto tarda 2-3 minutos la primera vez
- Espera a que la terminal muestre el prompt

### 3. Ejecutar setup + start
```bash
cd ~/zelin-vps && bash setup.sh && bash start.sh
```

Si necesitas empezar de cero:
```bash
cd ~ && rm -rf zelin-vps vms novnc && git clone https://github.com/tomatesmp-crypto/zelin-vps.git && cd zelin-vps && bash setup.sh && bash start.sh
```

## SSH

```bash
ssh zelin@localhost -p 2222
# Password: zelin2026
```

El script crea automaticamente un Cloudflare Tunnel que te da una URL publica para SSH remoto.

## Importante

- **Rebuild Environment**: Si rebuildeas, se borra TODO. Tienes que clonar y ejecutar de nuevo
- **dev.nix tiene QEMU**: Los paquetes se instalan via Nix, no apt
- **Sin KVM**: Si no hay /dev/kvm la VM sera lenta pero funcional

## Specs

- OS: Ubuntu Server 22.04 LTS (via QEMU/KVM)
- CPU: 12 vCPU para la VM (16 total, 4 para host)
- RAM: 48 GB para la VM (64 total, 16 para host)
- Disco: 80 GB
- SSH: puerto 2222 (local) + Cloudflare Tunnel (remoto)
- VNC: puerto 6080 (preview Firebase Studio)
