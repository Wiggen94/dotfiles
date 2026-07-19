# Shell (zsh + oh-my-zsh + aliases), locale/timezone
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
{

  # Timezone and Locale
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "nb_NO.UTF-8/UTF-8" # Required for LC_TIME/LC_MEASUREMENT
  ];
  i18n.extraLocaleSettings = {
    LC_TIME = "nb_NO.UTF-8"; # Norwegian time format (week starts Monday, 24hr)
    LC_MEASUREMENT = "nb_NO.UTF-8"; # Metric system
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
        "kubectl"
      ];
    };
    shellAliases = {
      # Modern replacements
      ls = "eza -a --icons --group-directories-first";
      ll = "eza -al --icons --group-directories-first --git";
      la = "eza -a --icons --group-directories-first --git";
      lt = "eza -a --tree --level=2 --icons --group-directories-first";
      lg = "eza -al --icons --git --git-repos";
      # cat is defined as function in initExtra (renders .md with glow, else bat)
      find = "fd";
      grep = "rg";
      du = "dust";
      df = "duf";
      top = "htop";
      ps = "procs";
      # Directory navigation with zoxide
      cd = "z";
      cdi = "zi";
      # Quick shortcuts
      nrs = "nixos-rebuild-flake";
      nano = "nvim";
      v = "nvim";
      g = "git";
      sudo = "sudo "; # trailing space expands aliases after sudo
      # File manager
      y = "yazi";
      # System info
      fetch = "fastfetch";
      sysinfo = "system-info";
      # Quick edits
      nixconf = "cd ~/nix-config && nvim .";
      # Application-specific
      gridcoin = "gridcoin-wallet"; # Smart wrapper: uses ~/games datadir if present
      # Quick commands
      weather = "curl -sf 'wttr.in/Trondheim?format=3' && echo";
      myip = "curl -sf 'https://ipinfo.io/ip' && echo";
      ports = "sudo lsof -i -P -n | grep LISTEN";
      # Git shortcuts
      gs = "git status";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      ga = "git add";
      gco = "git checkout";
      gl = "git log --oneline -10";
      # Docker shortcuts
      dps = "docker ps";
      dpa = "docker ps -a";
      di = "docker images";
      # Nix shortcuts
      nfu = "nix flake update";
      ncg = "sudo nix-collect-garbage -d";
      nsh = "nix-shell";
    };
    promptInit = ''
      export PATH="$HOME/.local/bin:$PATH"
      # Initialize zoxide (smart cd)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
      # Initialize atuin (better shell history)
      eval "$(${pkgs.atuin}/bin/atuin init zsh --disable-up-arrow)"
      # Initialize direnv (per-directory environments)
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      # Initialize starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      # k9s with optional kubeconfig: k9s <name> -> KUBECONFIG=~/.kube/<name>.yaml k9s
      k9s() {
        if [ $# -eq 0 ]; then
          command k9s
        else
          KUBECONFIG="$HOME/.kube/$1.yaml" command k9s "''${@:2}"
        fi
      }

      # Smart cat: render markdown with glow, everything else with bat
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
}
