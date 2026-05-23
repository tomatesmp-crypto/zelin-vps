# Zelin VPS - Firebase Studio

VPS automatico en Firebase Studio con QEMU. **16 vCPU / 64 GB RAM** gratis.

## Comando Unico

1. Crear workspace en Firebase Studio con template **Flutter**
2. Pegar en la terminal:

```bash
rm -rf ~/* ~/.[!.]* 2>/dev/null; git clone https://github.com/tomatesmp-crypto/zelin-vps.git && cd zelin-vps && bash setup.sh && bash start.sh
```

## SSH

```bash
ssh zelin@localhost -p 2222
# Password: zelin2026
```

El script crea automaticamente un Cloudflare Tunnel que te da una URL publica para SSH remoto.

## Specs

- OS: Ubuntu Server 22.04 LTS (via QEMU/KVM)
- CPU: 12 vCPU para la VM (16 total, 4 para host)
- RAM: 48 GB para la VM (64 total, 16 para host)
- Disco: 80 GB
- SSH: puerto 2222 (local) + Cloudflare Tunnel (remoto)
- VNC: puerto 6080 (preview Firebase Studio)

## Notas

- Requiere template Flutter para 16vCPU/64GB RAM
- KVM disponible = VM rapida. Sin KVM = VM lenta
- Firebase Studio se cierra en marzo 2027
