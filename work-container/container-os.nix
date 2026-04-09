# OS-level config for the work container

{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";

  # Match host UID so Wayland socket access works
  users.users.gjermund = {
    uid = 1000;
    isNormalUser = true;
    home = "/home/gjermund";
  };

  environment.systemPackages = with pkgs; [
    vivaldi
  ];

  # Zsh — mirrors host config from common.nix
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "git" "sudo" "kubectl" ];
    };
    shellAliases = {
      ls = "eza -a --icons --group-directories-first";
      ll = "eza -al --icons --group-directories-first --git";
      la = "eza -a --icons --group-directories-first --git";
      lt = "eza -a --tree --level=2 --icons --group-directories-first";
      lg = "eza -al --icons --git --git-repos";
      find = "fd";
      grep = "rg";
      du = "dust";
      df = "duf";
      top = "htop";
      ps = "procs";
      cd = "z";
      cdi = "zi";
      g = "git";
      sudo = "sudo ";
      y = "yazi";
      fetch = "fastfetch";
      weather = "curl -sf 'wttr.in/Trondheim?format=3' && echo";
      myip = "curl -sf 'https://ipinfo.io/ip' && echo";
      ports = "sudo lsof -i -P -n | grep LISTEN";
      gs = "git status";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      ga = "git add";
      gco = "git checkout";
      gl = "git log --oneline -10";
      nfu = "nix flake update";
      ncg = "sudo nix-collect-garbage -d";
      nsh = "nix-shell";
    };
    promptInit = ''
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
      eval "$(${pkgs.atuin}/bin/atuin init zsh --disable-up-arrow)"
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      k9s() {
        if [ $# -eq 0 ]; then
          command k9s
        else
          KUBECONFIG="$HOME/.kube/$1.yaml" command k9s "''${@:2}"
        fi
      }

      cat() {
        if [ $# -eq 0 ]; then
          ${pkgs.bat}/bin/bat
        else
          for file in "$@"; do
            if [[ "$file" == *.md ]]; then
              ${pkgs.glow}/bin/glow "$file"
            else
              ${pkgs.bat}/bin/bat "$file"
            fi
          done
        fi
      }
    '';
  };

  users.users.gjermund.shell = pkgs.zsh;

  # WireGuard — config bind-mounted from host at /etc/wireguard/work.conf
  networking.wg-quick.interfaces.work = {
    configFile = "/etc/wireguard/work.conf";
    autostart = true;
  };

  # Create mount point for the host Wayland/dbus socket dir
  systemd.tmpfiles.rules = [
    "d /var/wayland-socket 0700 gjermund users -"
  ];

  # GPU access for Vulkan/wgpu (needed by alacritty, vivaldi)
  hardware.graphics.enable = true;

  networking.useDHCP = false;

  # Default route via host veth (before WireGuard comes up)
  networking.defaultGateway = "192.168.100.1";
  networking.nameservers = [ "1.1.1.1" ];
}
