{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = with pkgs; [
    qemu
    qemu_kvm
    cloud-utils
    cdrkit
    unzip
    openssh
    git
    wget
    curl
    sudo
    tmux
    htop
    nano
    nodejs_20
    npm
    python3
  ];

  env = {
    EDITOR = "nano";
  };

  idx = {
    workspace = {
      onCreate = {
        setup = "bash setup.sh";
      };
      onStart = {
        start = "bash start.sh";
      };
    };

    previews = {
      enable = true;
      previews = {
        vnc = {
          command = "websockify --web /usr/share/novnc/ 6080 localhost:5900";
          manager = "web";
          env = { PORT = "6080"; };
        };
      };
    };
  };
}
