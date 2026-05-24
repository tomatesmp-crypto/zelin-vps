# Zelin VPS - Firebase Studio
# QEMU VM with SSH access + Cloudflare Tunnel
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    # QEMU - the core VM engine
    pkgs.qemu

    # ISO creation for cloud-init
    pkgs.cdrtools

    # noVNC dependencies
    pkgs.python3
    pkgs.python3Packages.websockify

    # Network tools
    pkgs.curl
    pkgs.wget
    pkgs.git
    pkgs.openssh

    # System utilities
    pkgs.htop
    pkgs.tmux
    pkgs.nano
    pkgs.jq
  ];

  env = {
    QEMU_SYSTEM_X86_64 = "${pkgs.qemu}/bin/qemu-system-x86_64";
  };

  idx = {
    extensions = [];
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["python3" "-m" "http.server" "6080"];
          manager = "web";
          env = {
            PORT = "6080";
          };
        };
      };
    };
  };
}

