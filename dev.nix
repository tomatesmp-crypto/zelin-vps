{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.qemu
    pkgs.cdrtools
    pkgs.python3
    pkgs.python3Packages.websockify
    pkgs.curl
    pkgs.wget
    pkgs.git
    pkgs.openssh
    pkgs.htop
    pkgs.tmux
    pkgs.nano
    pkgs.jq
  ];

  env = {};

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
