# git, ssh, thunderbird, yazi, starship, btop, lazygit, vscode
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:
let
  # Static Catppuccin Mocha palette (the 12-theme system is gone — omarchy
  # owns theming; yazi/lazygit keep their fixed catppuccin colors).
  colors = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    subtext1 = "#bac2de";
    lavender = "#b4befe";
    blue = "#89b4fa";
    sapphire = "#74c7ec";
    sky = "#89dceb";
    teal = "#94e2d5";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    peach = "#fab387";
    maroon = "#eba0ac";
    red = "#f38ba8";
    mauve = "#cba6f7";
    pink = "#f5c2e7";
    flamingo = "#f2cdcd";
    rosewater = "#f5e0dc";
    fonts = {
      monospace = "JetBrainsMono Nerd Font";
      sansSerif = "Inter";
      serif = "Noto Serif";
    };
  };
in
{
  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gjermund Wiggen";
        email = "gjermund.wiggen@sikt.no";
        signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCFErYzeQDyksloDzmjx72vft5FYqiBW87Z7/nY70JSWIAfKz6970jCG1ObCKQ0kPMukY0pKrHJZVHAGOwRYTUtnF+7OAB26On5QNdphoJg1BVtRnNAfyQiV9DhsTzVQsGO/3+DI7EbhaaVNsY4kJEJjXmwu+KKxFAW8DObwpi/sKh5lyXQgNFupR8jork5g6XLAD77U3ZqrQXJfJtkVP0yOd9bUbbprLb0nAzwDLyLhXtSgbAexAN0nloqjU4S8CetiMQB3JWmA/8Uam7mxbOGV+u4yYPgjorlC1u6JOipO/os01MzHfcqrDMztk5kFCJy8mCNUTfu4kQVbVUrlyN";
      };
      gpg = {
        format = "ssh";
        ssh.program = "/run/current-system/sw/bin/op-ssh-sign";
      };
      commit.gpgsign = true;
    };
  };

  # SSH client configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*.uninett.no" = {
        ForwardAgent = "yes";
      };
      "*" = {
        User = "gjewig";
        SetEnv = {
          TERM = "xterm-256color";
        };
        IdentityAgent = "~/.1password/agent.sock";
      };
    };
  };

  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
    };
  };

  # YAZI - Modern Terminal File Manager
  # ═══════════════════════════════════════════════════════════════════════════
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # Adopt the new default wrapper name ("y" instead of the legacy "yy")
    shellWrapperName = "y";
    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };
      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        image_filter = "triangle";
        image_quality = 75;
        sixel_fraction = 15;
        ueberzug_scale = 1;
        ueberzug_offset = [
          0
          0
          0
          0
        ];
      };
      opener = {
        edit = [
          {
            run = ''nvim "$@"'';
            block = true;
            for = "unix";
          }
        ];
        open = [
          {
            run = ''xdg-open "$@"'';
            desc = "Open";
            for = "linux";
          }
        ];
        reveal = [
          {
            run = ''xdg-open "$(dirname "$0")"'';
            desc = "Reveal";
            for = "linux";
          }
        ];
      };
    };
    # Catppuccin Mocha theme for Yazi
    theme = {
      manager = {
        cwd = {
          fg = "${colors.teal}";
        };
        hovered = {
          bg = "${colors.surface0}";
        };
        preview_hovered = {
          underline = true;
        };
        find_keyword = {
          fg = "${colors.yellow}";
          italic = true;
        };
        find_position = {
          fg = "${colors.pink}";
          bg = "reset";
          italic = true;
        };
        marker_selected = {
          fg = "${colors.green}";
          bg = "${colors.green}";
        };
        marker_copied = {
          fg = "${colors.yellow}";
          bg = "${colors.yellow}";
        };
        marker_cut = {
          fg = "${colors.red}";
          bg = "${colors.red}";
        };
        tab_active = {
          fg = "${colors.base}";
          bg = "${colors.mauve}";
        };
        tab_inactive = {
          fg = "${colors.text}";
          bg = "${colors.surface1}";
        };
        tab_width = 1;
        border_symbol = "│";
        border_style = {
          fg = "${colors.surface1}";
        };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = {
          fg = "${colors.surface1}";
          bg = "${colors.surface1}";
        };
        mode_normal = {
          fg = "${colors.base}";
          bg = "${colors.blue}";
          bold = true;
        };
        mode_select = {
          fg = "${colors.base}";
          bg = "${colors.green}";
          bold = true;
        };
        mode_unset = {
          fg = "${colors.base}";
          bg = "${colors.flamingo}";
          bold = true;
        };
        progress_label = {
          fg = "${colors.text}";
          bold = true;
        };
        progress_normal = {
          fg = "${colors.blue}";
          bg = "${colors.surface1}";
        };
        progress_error = {
          fg = "${colors.red}";
          bg = "${colors.surface1}";
        };
        permissions_t = {
          fg = "${colors.blue}";
        };
        permissions_r = {
          fg = "${colors.yellow}";
        };
        permissions_w = {
          fg = "${colors.red}";
        };
        permissions_x = {
          fg = "${colors.green}";
        };
        permissions_s = {
          fg = "${colors.overlay1}";
        };
      };
      input = {
        border = {
          fg = "${colors.mauve}";
        };
        title = { };
        value = { };
        selected = {
          reversed = true;
        };
      };
      select = {
        border = {
          fg = "${colors.mauve}";
        };
        active = {
          fg = "${colors.pink}";
        };
        inactive = { };
      };
      tasks = {
        border = {
          fg = "${colors.mauve}";
        };
        title = { };
        hovered = {
          underline = true;
        };
      };
      which = {
        mask = {
          bg = "${colors.surface0}";
        };
        cand = {
          fg = "${colors.teal}";
        };
        rest = {
          fg = "${colors.overlay1}";
        };
        desc = {
          fg = "${colors.pink}";
        };
        separator = " ➜ ";
        separator_style = {
          fg = "${colors.surface2}";
        };
      };
      help = {
        on = {
          fg = "${colors.pink}";
        };
        exec = {
          fg = "${colors.teal}";
        };
        desc = {
          fg = "${colors.overlay1}";
        };
        hovered = {
          bg = "${colors.surface0}";
          bold = true;
        };
        footer = {
          fg = "${colors.surface1}";
          bg = "${colors.text}";
        };
      };
      filetype = {
        rules = [
          {
            mime = "image/*";
            fg = "${colors.teal}";
          }
          {
            mime = "video/*";
            fg = "${colors.yellow}";
          }
          {
            mime = "audio/*";
            fg = "${colors.yellow}";
          }
          {
            mime = "application/zip";
            fg = "${colors.pink}";
          }
          {
            mime = "application/gzip";
            fg = "${colors.pink}";
          }
          {
            mime = "application/x-tar";
            fg = "${colors.pink}";
          }
          {
            mime = "application/x-7z-compressed";
            fg = "${colors.pink}";
          }
          {
            mime = "application/x-rar";
            fg = "${colors.pink}";
          }
          {
            mime = "application/pdf";
            fg = "${colors.red}";
          }
          {
            name = "*";
            fg = "${colors.text}";
          }
          {
            name = "*/";
            fg = "${colors.blue}";
          }
        ];
      };
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # STARSHIP - Modern Cross-Shell Prompt (config managed by theme-switcher)
  # ═══════════════════════════════════════════════════════════════════════════
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Settings follow the active omarchy theme (theme-set writes
    # ~/.local/state/omarchy/current/theme/starship.toml)
  };

  # (btop config + theme are owned by omarchy's HM module — see
  # modules/omarchy-hm.nix)

  # lazygit configuration - Catppuccin Mocha theme
  xdg.configFile."lazygit/config.yml".text = ''
    # Catppuccin Mocha theme for lazygit
    # https://github.com/catppuccin/lazygit
    gui:
      nerdFontsVersion: "3"
      theme:
        activeBorderColor:
          - "${colors.blue}"
          - bold
        inactiveBorderColor:
          - "${colors.subtext0}"
        optionsTextColor:
          - "${colors.blue}"
        selectedLineBgColor:
          - "${colors.surface0}"
        cherryPickedCommitBgColor:
          - "${colors.surface1}"
        cherryPickedCommitFgColor:
          - "${colors.blue}"
        unstagedChangesColor:
          - "${colors.red}"
        defaultFgColor:
          - "${colors.text}"
        searchingActiveBorderColor:
          - "${colors.yellow}"
      authorColors:
        "*": "${colors.lavender}"
  '';

  # VSCode configuration with Catppuccin theme
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons
      ];
      userSettings = {
        # Theme
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";

        # Font
        "editor.fontFamily" = "'${colors.fonts.monospace}', 'monospace', monospace";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = "'${colors.fonts.monospace}'";
        "terminal.integrated.fontSize" = 14;

        # Editor appearance
        "editor.cursorBlinking" = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.smoothScrolling" = true;
        "workbench.list.smoothScrolling" = true;
        "terminal.integrated.smoothScrolling" = true;

        # Window
        "window.titleBarStyle" = "custom";
        "window.menuBarVisibility" = "toggle";

        # Catppuccin accent color (mauve)
        "catppuccin.accentColor" = "mauve";
      };
    };
  };
}
