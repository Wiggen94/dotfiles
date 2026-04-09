# home-manager config for the work container user

{ pkgs, ... }:

{
  home.username = "gjermund";
  home.homeDirectory = "/home/gjermund";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Starship prompt (config managed by theme-switcher on host;
  # inside the container it uses default starship config)
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # --- Alacritty (Catppuccin Mocha) ---

  programs.alacritty = {
    enable = true;
    settings = {
      general.live_config_reload = true;
      env.TERM = "xterm-256color";

      window = {
        padding = { x = 12; y = 12; };
        decorations = "full";
        opacity = 0.95;
        dynamic_padding = true;
        dimensions = { columns = 180; lines = 50; };
      };

      scrolling.history = 10000;

      font = {
        normal = { family = "JetBrainsMono Nerd Font"; style = "Regular"; };
        bold = { family = "JetBrainsMono Nerd Font"; style = "Bold"; };
        italic = { family = "JetBrainsMono Nerd Font"; style = "Italic"; };
        size = 13.0;
      };

      cursor = {
        style = { shape = "Block"; blinking = "On"; };
        blink_interval = 500;
      };

      selection.save_to_clipboard = true;

      colors = {
        primary = {
          background = "#1e1e2e";
          foreground = "#cdd6f4";
          dim_foreground = "#7f849c";
        };
        cursor = { text = "#1e1e2e"; cursor = "#f5e0dc"; };
        vi_mode_cursor = { text = "#1e1e2e"; cursor = "#b4befe"; };
        search = {
          matches = { foreground = "#1e1e2e"; background = "#a6adc8"; };
          focused_match = { foreground = "#1e1e2e"; background = "#a6e3a1"; };
        };
        selection = { text = "#1e1e2e"; background = "#f5e0dc"; };
        normal = {
          black = "#45475a"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af";
          blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#bac2de";
        };
        bright = {
          black = "#585b70"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af";
          blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#a6adc8";
        };
        indexed_colors = [
          { index = 16; color = "#fab387"; }
          { index = 17; color = "#f5e0dc"; }
        ];
      };

      keyboard.bindings = [
        { key = "V"; mods = "Control|Shift"; action = "Paste"; }
        { key = "C"; mods = "Control|Shift"; action = "Copy"; }
        { key = "Plus"; mods = "Control"; action = "IncreaseFontSize"; }
        { key = "Minus"; mods = "Control"; action = "DecreaseFontSize"; }
        { key = "Key0"; mods = "Control"; action = "ResetFontSize"; }
      ];
    };
  };

  # --- Packages ---

  home.packages = with pkgs; [
    # Fonts
    nerd-fonts.jetbrains-mono

    # Shell tools (needed by zsh aliases in container-os.nix)
    eza
    bat
    glow
    zoxide
    atuin
    direnv
    starship
    fd
    ripgrep
    dust
    duf
    htop
    procs
    fastfetch
    yazi
    vivid

    # Work tools
    (pkgs.callPackage ../curitz.nix {})

    # Dev/ops tools
    gcc
    lazygit
    nodejs
    wl-clipboard
    git
    curl
    openssh
    kubectl
    k9s
    btop
    age
    sops
  ];

  # --- Tmux (Catppuccin Mocha) ---

  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 10000;
    baseIndex = 1;

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'mocha'
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_status_modules_right "session user host"
          set -g @catppuccin_status_left_separator "█"
          set -g @catppuccin_status_right_separator "█"
        '';
      }
      vim-tmux-navigator
      {
        plugin = yank;
        extraConfig = ''
          set -g @yank_selection_mouse 'clipboard'
        '';
      }
    ];

    extraConfig = ''
      set -ag terminal-overrides ",xterm-256color:RGB"
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %
      bind c new-window -c "#{pane_current_path}"
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -r C-h resize-pane -L 5
      bind -r C-j resize-pane -D 5
      bind -r C-k resize-pane -U 5
      bind -r C-l resize-pane -R 5
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"
      set -g automatic-rename off
      set -g allow-rename off
      set -g renumber-windows on
      set -g focus-events on
      set -g set-clipboard on
    '';
  };
}
