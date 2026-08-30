# System packages + custom writeShellScriptBin tools (incl. nrs)
{
  config,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}:
let
  isWorkHost = hostName == "sikt";
  # Extracts the embedded icon from AppImages for Nautilus thumbnails.
  # AppImages are an ELF runtime with a squashfs appended — the superblock
  # offset varies per build, so scan for the first valid one.
  appimage-thumbnailer = pkgs.writeShellScriptBin "appimage-thumbnailer" ''
    export PATH="${lib.makeBinPath [
      pkgs.squashfs-tools
      pkgs.imagemagick
      pkgs.gnugrep
      pkgs.findutils
      pkgs.coreutils
    ]}:$PATH"
    input="$1"; output="$2"; size="$3"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    off=""
    while IFS=: read -r pos _; do
      if unsquashfs -s -o "$pos" "$input" >/dev/null 2>&1; then off="$pos"; break; fi
    done < <(grep -abo 'hsqs' "$input")
    [ -n "$off" ] || exit 1

    # .DirIcon is a symlink to the embedded icon (-follow resolves chains)
    unsquashfs -quiet -follow -o "$off" -dest "$tmp" "$input" .DirIcon 2>/dev/null
    icon="$tmp/.DirIcon"
    if [ ! -f "$icon" ]; then
      # tauri-built AppImages can point .DirIcon at an absolute build-machine
      # path that's absent from the archive — fall back to any hicolor icon
      unsquashfs -quiet -o "$off" -dest "$tmp" "$input" 'usr/share/icons/hicolor/*/apps/*' 2>/dev/null
      icon="$(find "$tmp" -path '*hicolor*apps*' -type f \( -name '*.png' -o -name '*.svg' \) -printf '%s %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
    fi
    [ -n "$icon" ] || exit 1
    magick "$icon" -thumbnail "''${size}x''${size}" "$output" 2>/dev/null
  '';

  # niri gaming-mode override. Dropped in as ~/.config/niri/gaming.kdl by the
  # `gaming-mode` script and optional-included at the tail of the generated
  # niri config (modules/home/niri.nix), so its values win (includes are
  # positional). niri live-reloads included files, so this flips without a
  # compositor restart. In an included file `border {}` alone is a no-op —
  # `off` is required to actually disable it (niri "border special case").
  niriGamingKdl = pkgs.writeText "niri-gaming.kdl" ''
    // Written by `gaming-mode` — do not edit. Remove the file to exit gaming mode.
    layout {
        gaps 0
        struts { left 0; right 0; top 0; bottom 0; }
        border { off; }
        focus-ring { off; }
    }
    // Cancels the base geometry-corner-radius 18 rule. Included after it, so
    // for a window matched by both the later rule wins (niri: window rules
    // from includes are inserted at the include position, not merged).
    window-rule {
        geometry-corner-radius 0
        clip-to-geometry false
    }
  '';
in
{

  environment.systemPackages = [
    # ═══════════════════════════════════════════════════════════════════════════
    # X11 FORWARDING
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.xauth # Required for SSH X11 forwarding
    pkgs.setxkbmap # Set XWayland keymap at session start (XWayland ignores Hyprland's wl keymap)

    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN CLI TOOLS - Rust-powered replacements for classic Unix utilities
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.eza # ls replacement with icons, git integration
    pkgs.bat # cat replacement with syntax highlighting
    pkgs.charm-freeze # render terminal output/commands to PNG (used by `shot`)
    pkgs.glow # Terminal markdown renderer
    pkgs.fd # find replacement, faster and more intuitive
    pkgs.ripgrep # grep replacement, blazingly fast
    pkgs.dust # du replacement, visual disk usage
    pkgs.duf # df replacement, modern disk usage
    pkgs.procs # ps replacement, better process viewer
    pkgs.sd # sed replacement, simpler syntax
    pkgs.choose # cut/awk replacement, human-friendly field selection
    pkgs.hyperfine # Command benchmarking tool
    pkgs.tokei # Code statistics (lines of code by language)
    pkgs.powertop # Power consumption analyzer (useful on laptops)
    pkgs.vulkan-tools # Vulkan utilities (vulkaninfo) — all GPUs
    pkgs.mesa-demos # OpenGL info (glxinfo, glxgears) — all GPUs
    pkgs.libva-utils # VA-API info (vainfo) — all GPUs
    pkgs.gping # ping with graph visualization
    pkgs.doggo # dig replacement, modern DNS client
    pkgs.hexyl # Modern hex viewer
    pkgs.delta # Better git diff viewer
    pkgs.zoxide # Smart cd that learns your habits
    pkgs.atuin # Shell history with sync and fuzzy search
    pkgs.direnv # Per-directory environment variables
    pkgs.nix-direnv # Direnv integration for Nix
    pkgs.yazi # Terminal file manager (blazingly fast)
    pkgs.tealdeer # tldr pages - simplified man pages
    pkgs.navi # Interactive cheatsheet tool
    pkgs.fzf # Fuzzy finder

    # ═══════════════════════════════════════════════════════════════════════════
    # SYSTEM INFORMATION & MONITORING
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.fastfetch # System info like neofetch but faster
    pkgs.htop # Interactive process viewer
    pkgs.btop # System monitor with Catppuccin theme
    pkgs.nvtopPackages.full # NVIDIA GPU monitor
    pkgs.lm_sensors # Hardware sensors (run 'sensors' command)
    pkgs.bandwhich # Network utilization by process
    pkgs.lsof # List open files
    pkgs.psmisc # killall/fuser

    # ═══════════════════════════════════════════════════════════════════════════
    # GIT TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.git
    pkgs.lazygit # Terminal UI for git
    pkgs.gh # GitHub CLI
    pkgs.glab # GitLab CLI
    pkgs.git-crypt # Encrypt files in git repos

    # ═══════════════════════════════════════════════════════════════════════════
    # SYSTEM UTILITIES
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.jq # JSON processor
    pkgs.yq-go # YAML processor (like jq but for YAML)
    pkgs.nvd # Nix/NixOS package version diff tool (used by nh)
    pkgs.bluez # Package needed for D-Bus files
    pkgs.seahorse # GNOME keyring GUI + SSH askpass
    pkgs.shared-mime-info # MIME type database
    pkgs.file # file type detection (used by omarchy-webapp-install)
    pkgs.glib # For gio and other utilities
    pkgs.traceroute
    pkgs.bind
    pkgs.wtype # Wayland keyboard/mouse input simulator
    pkgs.evsieve # Input device event remapping
    pkgs.socat # For Hyprland socket monitoring (monitor-handler)
    pkgs.freerdp # Modern RDP client (xfreerdp) - wrapped via overlay for Winboat
    pkgs.remmina # Feature-rich remote desktop client (RDP, VNC, SSH, SPICE)
    pkgs.rclone # Cloud storage sync (SharePoint, OneDrive, etc.)
    pkgs.wget
    pkgs.unzip
    pkgs.zip
    pkgs.p7zip # 7zip support
    pkgs.unrar # RAR archive extraction
    pkgs.python3
    pkgs.tree # Directory tree visualization

    # Shell (zsh; oh-my-zsh + plugins are gone — zplug owns zsh)
    pkgs.zsh

    # Desktop environment & UI (omarchy's shell owns bar/lockscreen/power
    # menu/launcher/clipboard — vicinae and cliphist are gone)
    pkgs.alacritty
    pkgs.nautilus # Files (GNOME) - default file manager
    pkgs.loupe # GNOME image viewer
    # AppImage thumbnails in Nautilus (script above + thumbnailer registration)
    appimage-thumbnailer
    (pkgs.runCommand "appimage-thumbnailers" { } ''
      mkdir -p "$out/share/thumbnailers"
      cat > "$out/share/thumbnailers/appimage.thumbnailer" <<EOF
      [Thumbnailer Entry]
      Exec=${appimage-thumbnailer}/bin/appimage-thumbnailer %i %o %s
      MimeType=application/vnd.appimage;
      EOF
    '')
    pkgs.pavucontrol # PulseAudio/PipeWire volume control GUI
    pkgs.inotify-tools # omarchy-shell live-reloads ~/.config/omarchy/plugins via inotifywait
    pkgs.libxkbcommon # omarchy-shell's xkbcli enumerates keyboard layouts

    # Clipboard & Screenshots (clipboard history is omarchy's clipboard
    # plugin; wl-clip-persist keeps the clipboard alive after apps close)
    pkgs.wl-clipboard # Wayland clipboard utilities
    pkgs.wl-clip-persist # Keep clipboard after programs close
    pkgs.grim # Screenshot utility
    pkgs.slurp # Region selection
    pkgs.libnotify # For notifications (notify-send)
    # (swaync is gone — omarchy's shell owns notifications)

    # Idle daemon (lockscreen handled by quickshell) — kept for its
    # sleep hooks (loginctl lock-session before sleep, DPMS restore after).
    pkgs.hypridle

    # Inhibits idle whenever any app plays audio through PipeWire
    # (browsers, mpv, ...). Zen only holds a Wayland idle inhibitor for
    # *fullscreen* video, so windowed YouTube used to hit the 5-minute
    # omarchy-shell lock. Runs as a user service — see modules/home/services.nix.
    pkgs.wayland-pipewire-idle-inhibit

    # ═══════════════════════════════════════════════════════════════════════════
    # ANIMATED WALLPAPER & VISUAL EFFECTS
    # ═══════════════════════════════════════════════════════════════════════════
    # (awww/waypaper are gone — omarchy owns wallpapers)
    pkgs.pyprland # Scratchpads, dropdown terminals, and more

    # ═══════════════════════════════════════════════════════════════════════════
    # MODERN TERMINAL OPTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.starship # Cross-shell prompt (alternative to p10k)

    # ═══════════════════════════════════════════════════════════════════════════
    # DEVELOPMENT ENVIRONMENT TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    pkgs.devenv # Fast, declarative development environments
    pkgs.nodejs_22 # Node.js 22 (required for openclaw)
    pkgs.gnumake # Build tool
    pkgs.cmake # Build system
    pkgs.gcc # C/C++ compiler
    pkgs.go # Go programming language
    pkgs.postman # API development and testing tool
    pkgs.opencode # AI coding agent for the terminal
    pkgs.codex # OpenAI Codex CLI coding agent
    pkgs.bun # Fast JavaScript runtime and toolkit
    pkgs.uv # Fast Python package manager (pip/pipx/venv replacement)

    # (nm-applet is gone — omarchy's shell owns network status, and the
    # autostart entry for it is dropped in omarchy-hm.nix)

    # KDE Connect
    pkgs.kdePackages.kdeconnect-kde

    # Media control
    pkgs.playerctl

    # Notification sounds
    pkgs.sound-theme-freedesktop
    pkgs.libcanberra-gtk3

    # Brightness control (useful for laptops)
    pkgs.brightnessctl

    # Calculator
    pkgs.qalculate-gtk # Powerful calculator with unit conversions

    # Screenshot script with notification and save action
    (pkgs.writeShellScriptBin "screenshot" ''
      #!/usr/bin/env bash
      SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
      mkdir -p "$SCREENSHOTS_DIR"
      TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
      TEMP_FILE="/tmp/screenshot_$TIMESTAMP.png"

      # Take screenshot
      ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$TEMP_FILE"

      if [ -f "$TEMP_FILE" ]; then
        # Copy to clipboard
        ${pkgs.wl-clipboard}/bin/wl-copy < "$TEMP_FILE"

        # Show notification with save action
        ACTION=$(${pkgs.libnotify}/bin/notify-send \
          --app-name="Screenshot" \
          --icon="$TEMP_FILE" \
          --action="save=Save" \
          --action="discard=Discard" \
          "Screenshot captured" \
          "Copied to clipboard. Click Save to keep.")

        if [ "$ACTION" = "save" ]; then
          SAVE_PATH="$SCREENSHOTS_DIR/screenshot_$TIMESTAMP.png"
          mv "$TEMP_FILE" "$SAVE_PATH"
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$SAVE_PATH"
        else
          rm -f "$TEMP_FILE"
        fi
      fi
    '')

    # Pretty terminal screenshots: `shot 'command'` renders a windowed PNG of the
    # command (syntax-highlighted via bat) + its output, and copies it to clipboard.
    #   shot 'ls -la'             # command + output
    #   shot -c 'ls -la'          # command only (no run)
    #   shot -s out.png 'ls -la'  # also save a copy to out.png
    (pkgs.writeShellScriptBin "shot" ''
      #!/usr/bin/env bash
      CMD_ONLY=0
      SAVE=""
      while getopts "cs:h" opt; do
        case "$opt" in
          c) CMD_ONLY=1 ;;
          s) SAVE="$OPTARG" ;;
          h) echo "Usage: shot [-c] [-s out.png] 'command'"; exit 0 ;;
          *) echo "Usage: shot [-c] [-s out.png] 'command'" >&2; exit 1 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ $# -eq 0 ]; then
        echo "Usage: shot [-c] [-s out.png] 'command'" >&2
        exit 1
      fi

      CMD="$*"
      ANSI=$(mktemp --suffix=.ansi)
      IMG=$(mktemp --suffix=.png)
      trap 'rm -f "$ANSI" "$IMG"' EXIT

      {
        printf '\033[35m❯\033[0m '
        printf '%s\n' "$CMD" | ${pkgs.bat}/bin/bat --color=always -ppl bash
        if [ "$CMD_ONLY" -eq 0 ]; then
          eval "$CMD" 2>&1
        fi
      } > "$ANSI"

      ${pkgs.charm-freeze}/bin/freeze "$ANSI" -o "$IMG" \
        --window -r 8 -p 40 -m 0 --wrap 80

      ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$IMG"

      if [ -n "$SAVE" ]; then
        cp "$IMG" "$SAVE"
        ${pkgs.libnotify}/bin/notify-send "shot" "Saved to $SAVE and copied to clipboard"
      else
        ${pkgs.libnotify}/bin/notify-send "shot" "Copied to clipboard"
      fi
    '')

    # Notification sound daemon
    (pkgs.writeShellScriptBin "notification-sound-daemon" ''
      #!/usr/bin/env bash
      SOUND_FILE="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga"
      # Monitor D-Bus for notifications and play a sound
      ${pkgs.dbus}/bin/dbus-monitor "interface=org.freedesktop.Notifications" | \
      while read -r line; do
        if echo "$line" | grep -q "member=Notify"; then
          ${pkgs.pipewire}/bin/pw-play "$SOUND_FILE" &
        fi
      done
    '')

    # Volume control with sound feedback
    (pkgs.writeShellScriptBin "volume-up" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
      ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
    '')

    (pkgs.writeShellScriptBin "volume-down" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
    '')

    (pkgs.writeShellScriptBin "volume-mute" ''
      #!/usr/bin/env bash
      ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      # Only play feedback sound when unmuting (no sound when muting)
      MUTED=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo "yes" || echo "no")
      if [ "$MUTED" = "no" ]; then
        ${pkgs.pipewire}/bin/pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga &
      fi
    '')

    # SYSTEM INFORMATION & DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════════

    # Beautiful system info dashboard (like fastfetch but custom)
    (pkgs.writeShellScriptBin "system-info" ''
      #!/usr/bin/env bash
      # Catppuccin Mocha colors for output
      MAUVE='\033[38;2;203;166;247m'
      PINK='\033[38;2;245;194;231m'
      BLUE='\033[38;2;137;180;250m'
      TEAL='\033[38;2;148;226;213m'
      GREEN='\033[38;2;166;227;161m'
      YELLOW='\033[38;2;249;226;175m'
      PEACH='\033[38;2;250;179;135m'
      TEXT='\033[38;2;205;214;244m'
      SUBTEXT='\033[38;2;166;173;200m'
      RESET='\033[0m'
      BOLD='\033[1m'

      # Get system info
      HOSTNAME=$(hostname)
      KERNEL=$(uname -r)
      UPTIME=$(awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60);printf "%dd %dh %dm",d,h,m}' /proc/uptime)
      SHELL_NAME=$(basename "$SHELL")

      # CPU info
      CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
      CPU_CORES=$(nproc)
      CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)

      # Memory info
      MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
      MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
      MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

      # Disk info
      DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
      DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
      DISK_PERCENT=$(df -h / | awk 'NR==2 {gsub(/%/,""); print $5}')

      # GPU info
      GPU=""
      if command -v nvidia-smi &>/dev/null; then
        GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
      fi

      # NixOS info
      NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "Unknown")
      NIX_GENERATIONS=$(ls -1 /nix/var/nix/profiles/system-* 2>/dev/null | wc -l)

      # Print dashboard
      echo ""
      printf "''${MAUVE}''${BOLD}╭─────────────────────────────────────────────────────╮''${RESET}\n"
      printf "''${MAUVE}│''${RESET}   ''${PINK}''${BOLD}󰣇 NixOS System Information''${RESET}                       ''${MAUVE}│''${RESET}\n"
      printf "''${MAUVE}╰─────────────────────────────────────────────────────╯''${RESET}\n"
      echo ""
      printf "  ''${BLUE}󰟀 ''${TEXT}Hostname:''${RESET}    %s\n" "$HOSTNAME"
      printf "  ''${TEAL}󰻀 ''${TEXT}Kernel:''${RESET}      %s\n" "$KERNEL"
      printf "  ''${GREEN} ''${TEXT}Uptime:''${RESET}      %s\n" "$UPTIME"
      printf "  ''${YELLOW} ''${TEXT}Shell:''${RESET}       %s\n" "$SHELL_NAME"
      printf "  ''${PEACH}󰏖 ''${TEXT}NixOS:''${RESET}       %s (%d generations)\n" "$NIXOS_VERSION" "$NIX_GENERATIONS"
      echo ""
      printf "''${MAUVE}─────────────────────────────────────────────────────────''${RESET}\n"
      echo ""
      printf "  ''${BLUE}󰍛 ''${TEXT}CPU:''${RESET}         %s\n" "$CPU"
      printf "  ''${SUBTEXT}              %d cores @ %d%% usage''${RESET}\n" "$CPU_CORES" "$CPU_USAGE"
      printf "  ''${GREEN}󰆼 ''${TEXT}Memory:''${RESET}      %s / %s (%d%%)''${RESET}\n" "$MEM_USED" "$MEM_TOTAL" "$MEM_PERCENT"
      printf "  ''${YELLOW}󰋊 ''${TEXT}Disk:''${RESET}        %s / %s (%d%%)''${RESET}\n" "$DISK_USED" "$DISK_TOTAL" "$DISK_PERCENT"
      if [ -n "$GPU" ]; then
        printf "  ''${PEACH}󰢮 ''${TEXT}GPU:''${RESET}         %s\n" "$GPU"
      fi
      echo ""
      printf "''${MAUVE}─────────────────────────────────────────────────────────''${RESET}\n"
      echo ""

      # Color palette preview
      printf "  "
      for i in {0..7}; do
        printf "\033[4%dm   \033[0m" "$i"
      done
      echo ""
      printf "  "
      for i in {0..7}; do
        printf "\033[10%dm   \033[0m" "$i"
      done
      echo ""
      echo ""
    '')

    # Quick key bindings help (keep in sync with mkBindBlock in modules/home/_common.nix)
    (pkgs.writeShellScriptBin "keybinds" ''
      #!/usr/bin/env bash
      MAUVE='\033[38;2;203;166;247m'
      PINK='\033[38;2;245;194;231m'
      BLUE='\033[38;2;137;180;250m'
      TEXT='\033[38;2;205;214;244m'
      SUBTEXT='\033[38;2;166;173;200m'
      RESET='\033[0m'
      BOLD='\033[1m'

      echo ""
      printf "''${MAUVE}''${BOLD}╭─────────────────────────────────────────────────────╮''${RESET}\n"
      printf "''${MAUVE}│''${RESET}   ''${PINK}''${BOLD}󰌌 Hyprland Key Bindings''${RESET}                         ''${MAUVE}│''${RESET}\n"
      printf "''${MAUVE}╰─────────────────────────────────────────────────────╯''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Applications''${RESET}\n"
      printf "  ''${TEXT}Super+T''${RESET}             ''${SUBTEXT}Terminal (Alacritty)''${RESET}\n"
      printf "  ''${TEXT}Super+B''${RESET}             ''${SUBTEXT}Browser (Zen)''${RESET}\n"
      printf "  ''${TEXT}Super+E''${RESET}             ''${SUBTEXT}File Manager (Files)''${RESET}\n"
      printf "  ''${TEXT}Super+A / Super+Space''${RESET}  ''${SUBTEXT}App launcher (omarchy menu)''${RESET}\n"
      printf "  ''${TEXT}Super+C''${RESET}             ''${SUBTEXT}Calculator''${RESET}\n"
      printf "  ''${TEXT}Super+Y / Super+Shift+Y''${RESET} ''${SUBTEXT}Dropdown terminal / btop''${RESET}\n"
      printf "  ''${TEXT}Super+O''${RESET}             ''${SUBTEXT}Obsidian''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Windows''${RESET}\n"
      printf "  ''${TEXT}Super+Q''${RESET}             ''${SUBTEXT}Close window''${RESET}\n"
      printf "  ''${TEXT}Super+F''${RESET}             ''${SUBTEXT}Fullscreen''${RESET}\n"
      printf "  ''${TEXT}Super+W''${RESET}             ''${SUBTEXT}Toggle floating''${RESET}\n"
      printf "  ''${TEXT}Super+J''${RESET}             ''${SUBTEXT}Toggle split direction''${RESET}\n"
      printf "  ''${TEXT}Super+Tab''${RESET}           ''${SUBTEXT}Cycle windows''${RESET}\n"
      printf "  ''${TEXT}Super+Arrows''${RESET}        ''${SUBTEXT}Move focus''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+Arrows''${RESET}  ''${SUBTEXT}Resize window''${RESET}\n"
      printf "  ''${TEXT}Super+Ctrl+Arrows''${RESET}   ''${SUBTEXT}Move window''${RESET}\n"
      printf "  ''${TEXT}Super+Mouse Drag''${RESET}    ''${SUBTEXT}Move / resize window''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Workspaces''${RESET}\n"
      printf "  ''${TEXT}Super+1-9''${RESET}           ''${SUBTEXT}Switch to workspace''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+1-9''${RESET}     ''${SUBTEXT}Move window to workspace''${RESET}\n"
      printf "  ''${TEXT}Super+S''${RESET}             ''${SUBTEXT}Special workspace (scratchpad)''${RESET}\n"
      printf "  ''${TEXT}Super+Mouse Wheel''${RESET}   ''${SUBTEXT}Scroll through workspaces''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Utilities''${RESET}\n"
      printf "  ''${TEXT}Super+V / Super+Ctrl+V''${RESET} ''${SUBTEXT}Clipboard history (omarchy)''${RESET}\n"
      printf "  ''${TEXT}Super+P''${RESET}             ''${SUBTEXT}Screenshot (region)''${RESET}\n"
      printf "  ''${TEXT}Print''${RESET}               ''${SUBTEXT}Screenshot (omarchy)''${RESET}\n"
      printf "  ''${TEXT}Super+L''${RESET}             ''${SUBTEXT}Power menu''${RESET}\n"
      printf "  ''${TEXT}Super+Ctrl+L''${RESET}        ''${SUBTEXT}Lock screen''${RESET}\n"
      printf "  ''${TEXT}Super+N''${RESET}             ''${SUBTEXT}Notification history''${RESET}\n"
      printf "  ''${TEXT}Super+Comma''${RESET}         ''${SUBTEXT}Dismiss notification''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+B''${RESET}       ''${SUBTEXT}Toggle omarchy bar''${RESET}\n"
      printf "  ''${TEXT}Ctrl+Super+Tab''${RESET}      ''${SUBTEXT}Theme switcher''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+W''${RESET}       ''${SUBTEXT}Wallpaper picker''${RESET}\n"
      printf "  ''${TEXT}Super+Shift+Space''${RESET}   ''${SUBTEXT}Switch keyboard layout''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Media''${RESET}\n"
      printf "  ''${TEXT}XF86 Volume''${RESET}         ''${SUBTEXT}Volume up/down/mute (with sound)''${RESET}\n"
      printf "  ''${TEXT}XF86 Media''${RESET}          ''${SUBTEXT}Play/pause, next/previous track''${RESET}\n"
      printf "  ''${TEXT}XF86 Brightness''${RESET}     ''${SUBTEXT}Brightness up/down (laptop)''${RESET}\n"
      echo ""
      printf "  ''${BLUE}''${BOLD}Gaming''${RESET}\n"
      printf "  ''${TEXT}Super+G''${RESET}             ''${SUBTEXT}Gaming mode toggle''${RESET}\n"
      echo ""
    '')

    # niri gaming mode. niri has no runtime "set gaps" like `hyprctl keyword`,
    # but it hot-reloads included config files — so toggling the optional
    # include target (~/.config/niri/gaming.kdl) is how the flip happens.
    # Bound to Super+G in modules/home/niri.nix.
    (pkgs.writeShellScriptBin "gaming-mode" ''
      GAMING_KDL="''${XDG_CONFIG_HOME:-$HOME/.config}/niri/gaming.kdl"
      if [ -f "$GAMING_KDL" ]; then
        rm -f "$GAMING_KDL"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Disabled - gaps, borders and rounding restored"
      else
        install -Dm0644 ${niriGamingKdl} "$GAMING_KDL"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Enabled - gaps, borders and rounding off"
      fi
    '')

    # Gaming mode toggle script
    (pkgs.writeShellScriptBin "gaming-mode-toggle" ''
      #!/usr/bin/env bash
      STATE_FILE="/tmp/gaming-mode-state"

      # Check if gaming mode is currently enabled
      if [ -f "$STATE_FILE" ]; then
        # Currently in gaming mode, switch back to normal
        # Show bar if it was hidden
        if grep -q "bar_was_visible=1" "$STATE_FILE" 2>/dev/null; then
          hyprctl eval 'hl.dsp.global("quickshell:bartoggle")'
        fi
        # Restore to the CURRENT looknfeel (mkLooknfeelConfig in
        # modules/home/_common.nix: rounding 18, gaps 8/18, opacity
        # 0.98/0.90, dim_strength 0.15, dim_special 0.3). No windowrule
        # to undo: the framework's default-opacity rule is gone
        # (windows.lua shadow in omarchy-hm.nix).
        hyprctl eval 'hl.config({
          animations = { enabled = true },
          decoration = {
            rounding         = 18,
            active_opacity   = 0.98,
            inactive_opacity = 0.90,
            dim_inactive     = true,
            dim_strength     = 0.15,
            dim_special      = 0.3,
            shadow = { enabled = true },
            blur   = { enabled = true, size = 10, passes = 4, special = true, popups = true },
          },
          general = {
            gaps_in     = 8,
            gaps_out    = 18,
            border_size = 3,
            col = {
              active_border   = { colors = { "rgba(cba6f7ff)", "rgba(f5c2e7ff)", "rgba(89b4faff)" }, angle = 45 },
              inactive_border = "rgba(45475aaa)",
            },
          },
        })'
        rm -f "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Disabled - effects restored"
      else
        # Currently normal mode, switch to gaming mode
        # Hide bar and track if it was visible
        BAR_WAS_VISIBLE=0
        if [ ! -f /tmp/qs-bar-hidden ]; then
          BAR_WAS_VISIBLE=1
          hyprctl eval 'hl.dsp.global("quickshell:bartoggle")'
        fi
        # No dimming, no transparency: full opacity + dim off entirely
        # (incl. dim_strength/dim_special, which the normal-mode config
        # sets to 0.15/0.3 — dim_special would still dim scratchpad
        # windows otherwise). The normal-mode decoration is 0.98/0.90,
        # so this branch forces 1.0/1.0 explicitly. border_size 0 and
        # gaps 0/0: a maximized window is flush with every screen edge
        # (gaps_out 0 plus an empty monitor outer gap reads as a 1px
        # border line otherwise). No windowrule needed: the framework's
        # default-opacity rule is gone (windows.lua shadow in
        # omarchy-hm.nix).
        # NOTE: no `#` comments or `hyprctl keyword` inside this eval —
        # the Lua parser rejects both (comments are `--`; keyword needs
        # the legacy parser).
        hyprctl eval 'hl.config({
          animations = { enabled = false },
          decoration = {
            rounding         = 0,
            active_opacity   = 1.0,
            inactive_opacity = 1.0,
            dim_inactive     = false,
            dim_strength     = 0,
            dim_special      = 0,
            shadow = { enabled = false },
            blur   = { enabled = false, size = 0, passes = 0, special = false, popups = false },
          },
          general = {
            gaps_in     = 0,
            gaps_out    = 0,
            border_size = 0,
            col = {
              active_border   = "rgba(00000000)",
              inactive_border = "rgba(00000000)",
            },
          },
        })'
        echo "bar_was_visible=$BAR_WAS_VISIBLE" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -u low "Gaming Mode" "Enabled - max performance"
      fi
    '')

    # Mouse4 -> Enter when RuneLite is focused (evsieve daemon)
    (pkgs.writeShellScriptBin "runelite-mouse4-daemon" ''
      #!/usr/bin/env bash
      # Monitors Hyprland focus events and remaps mouse BTN_SIDE to Enter
      # only when RuneLite is the active window, using evsieve.

      # Auto-detect the active Logitech mouse by-id path. Prefers the PRO X 2
      # DEX, falls back to the first Logitech *-event-mouse found. Using by-id
      # keeps it stable across reboots/renumbering.
      find_mouse() {
        local d
        for d in /dev/input/by-id/*PRO_X_2_DEX*-event-mouse; do
          [ -e "$d" ] && { echo "$d"; return; }
        done
        for d in /dev/input/by-id/*Logitech*-event-mouse; do
          [ -e "$d" ] && { echo "$d"; return; }
        done
      }
      MOUSE_DEVICE="$(find_mouse)"
      EVSIEVE_PID=""

      cleanup() {
        [ -n "$EVSIEVE_PID" ] && kill "$EVSIEVE_PID" 2>/dev/null
        wait "$EVSIEVE_PID" 2>/dev/null
        exit 0
      }
      trap cleanup EXIT INT TERM

      start_remap() {
        if [ -z "$EVSIEVE_PID" ]; then
          # Re-detect in case the mouse was (re)connected after daemon start
          MOUSE_DEVICE="$(find_mouse)"
          [ -z "$MOUSE_DEVICE" ] && return
          sudo /run/current-system/sw/bin/evsieve --input "$MOUSE_DEVICE" grab \
            --map btn:side key:enter \
            --map btn:extra key:e \
            --output &
          EVSIEVE_PID=$!
        fi
      }

      stop_remap() {
        if [ -n "$EVSIEVE_PID" ]; then
          kill "$EVSIEVE_PID" 2>/dev/null
          wait "$EVSIEVE_PID" 2>/dev/null
          EVSIEVE_PID=""
        fi
      }

      check_window() {
        local class
        class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class // ""')
        if [[ "$class" == *"net-runelite"* ]]; then
          start_remap
        else
          stop_remap
        fi
      }

      # Check initial window
      check_window

      # Listen for active window changes via Hyprland IPC
      HYPR_SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$HYPR_SOCKET" | while IFS= read -r line; do
        case "$line" in
          activewindowv2*) check_window ;;
        esac
      done
    '')

    # Monitor hotplug handler - moves Waybar and workspaces when monitors change
    (pkgs.writeShellScriptBin "monitor-handler" ''
      #!/usr/bin/env bash
      # Listens to Hyprland socket for monitor events and handles hotplug
      # Run this at startup via exec-once

      DEBOUNCE_FILE="/tmp/monitor-handler-debounce"

      handle() {
        case $1 in
          monitorremoved*)
            # Debounce - ignore if we just handled an event
            if [ -f "$DEBOUNCE_FILE" ]; then
              LAST=$(cat "$DEBOUNCE_FILE")
              NOW=$(date +%s)
              if [ $((NOW - LAST)) -lt 2 ]; then
                return
              fi
            fi
            date +%s > "$DEBOUNCE_FILE"

            # A monitor was disconnected
            REMOVED="''${1#monitorremoved>>}"

            # Get remaining monitors
            REMAINING=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[0].name')

            if [ -n "$REMAINING" ]; then
              # Move all existing workspaces to remaining monitor
              WORKSPACES=$(hyprctl workspaces -j | ${pkgs.jq}/bin/jq -r '.[].id')
              for ws in $WORKSPACES; do
                hyprctl eval "hl.dsp.workspace.move({ id = '$ws', monitor = '$REMAINING' })" 2>/dev/null
              done

              # Focus the remaining monitor
              hyprctl eval "hl.dsp.focus({ monitor = '$REMAINING' })"
            fi

            # Quickshell auto-adapts to monitor changes
            true
            ;;
          monitoradded*)
            # Debounce
            if [ -f "$DEBOUNCE_FILE" ]; then
              LAST=$(cat "$DEBOUNCE_FILE")
              NOW=$(date +%s)
              if [ $((NOW - LAST)) -lt 2 ]; then
                return
              fi
            fi
            date +%s > "$DEBOUNCE_FILE"

            # A monitor was connected - wait and reload
            sleep 1
            hyprctl reload

            # Quickshell auto-adapts to monitor changes
            true
            ;;
        esac
      }

      # Listen to Hyprland socket (socket is in XDG_RUNTIME_DIR)
      SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
        handle "$line"
      done
    '')

    # Lid close handler for laptops - disables internal display when external monitors present
    (pkgs.writeShellScriptBin "lid-handler" ''
      #!/usr/bin/env bash
      # Called by Hyprland bindl for lid switch events
      # Usage: lid-handler open|close

      ACTION="$1"
      INTERNAL="eDP-1"

      # Count external monitors
      EXTERNAL_COUNT=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq "[.[] | select(.name != \"$INTERNAL\")] | length")

      if [ "$ACTION" = "close" ]; then
        if [ "$EXTERNAL_COUNT" -gt 0 ]; then
          # Lid closed with external monitors: disable internal display
          hyprctl eval "hl.monitor({ output = '$INTERNAL', disabled = true })"
          # Quickshell auto-adapts to monitor changes
          ${pkgs.libnotify}/bin/notify-send -t 2000 "Display" "Laptop screen disabled"
        fi
      elif [ "$ACTION" = "open" ]; then
        # Lid opened: re-enable internal display.
        # `disabled = false` is required — without it the prior `disabled = true`
        # sticks and the mode/position/scale fields are applied to a disabled monitor.
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = 'auto', scale = 1, disabled = false })"
        # Quickshell auto-adapts to monitor changes
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Display" "Laptop screen enabled"
      fi
    '')

    # Toggle mirroring the laptop panel onto a second monitor (meeting rooms,
    # projectors, any ad-hoc external display) - bound to SUPER+M. Relies on
    # hl.monitor's merge-with-existing-rule behavior: setting only `mirror`
    # leaves mode/position/scale untouched, so toggling off restores whatever
    # monitors.lua originally seeded for a known external, or the sensible
    # preferred/auto/auto default for one that was never seeded.
    (pkgs.writeShellScriptBin "monitor-mirror-toggle" ''
      #!/usr/bin/env bash
      # Usage: monitor-mirror-toggle [output]
      # Without an argument, auto-detects the sole external monitor. Pass an
      # output name (e.g. DP-1) explicitly when more than one is connected.
      set -euo pipefail

      MONITORS_JSON=$(hyprctl monitors -j)

      INTERNAL=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^eDP")) | .name' | head -n1)
      if [ -z "$INTERNAL" ]; then
        ${pkgs.libnotify}/bin/notify-send -t 3000 "Mirror" "No laptop screen (eDP-*) found"
        exit 1
      fi

      if [ -n "''${1:-}" ]; then
        EXT="$1"
      else
        EXTERNALS=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r --arg internal "$INTERNAL" '.[] | select(.name != $internal) | .name')
        COUNT=$(echo "$EXTERNALS" | grep -c . || true)
        if [ "$COUNT" -eq 0 ]; then
          ${pkgs.libnotify}/bin/notify-send -t 3000 "Mirror" "No second monitor connected"
          exit 1
        elif [ "$COUNT" -gt 1 ]; then
          ${pkgs.libnotify}/bin/notify-send -t 5000 "Mirror" "Multiple external monitors: $(echo "$EXTERNALS" | tr '\n' ' ')- run monitor-mirror-toggle <output>"
          exit 1
        fi
        EXT="$EXTERNALS"
      fi

      CURRENT_MIRROR=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r --arg ext "$EXT" '.[] | select(.name == $ext) | .mirrorOf // "none"')

      if [ "$CURRENT_MIRROR" = "$INTERNAL" ]; then
        hyprctl eval "hl.monitor({ output = '$EXT', mirror = ''' })"
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Mirror" "Extended mode restored on $EXT"
      else
        hyprctl eval "hl.monitor({ output = '$EXT', mirror = '$INTERNAL' })"
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Mirror" "Mirroring $INTERNAL -> $EXT"
      fi
    '')

    # Work applications
    pkgs.teams-for-linux
    pkgs.slack
    pkgs.zoom-us
    pkgs.discord
    # Matrix client for the self-hosted homeserver on k3s.
    # Hyprland's XDG_CURRENT_DESKTOP isn't recognised by Electron's keyring
    # auto-detection, so force the (working) gnome-keyring Secret Service backend.
    (pkgs.element-desktop.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
    pkgs.obsidian
    pkgs.mattermost-desktop
    # Unofficial Outlook desktop client (Electron wrapper), as an alternative
    # to the `outlook` Vivaldi --app= launcher below.
    (pkgs.callPackage ../../pkgs/prospect-mail { })
    pkgs.vivaldi
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.eduvpn-client
    pkgs.onlyoffice-desktopeditors
    (pkgs.writeShellScriptBin "outlook" ''
      #!/usr/bin/env bash
      exec vivaldi --app=https://outlook.office.com/mail/ "$@"
    '')

    # Development tools
    pkgs.claude-code

    # Separate Claude Code instance backed by DeepSeek's Anthropic-compatible
    # API. The API key is pulled from 1Password at launch (never stored in this
    # config, which lives in git). Uses its own config dir (~/.claude-deepseek)
    # so history/settings don't mix with the real Anthropic-backed `claude`.
    # Per https://api-docs.deepseek.com/quick_start/agent_integrations/claude_code
    (pkgs.writeShellScriptBin "dclaude" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Key resolution kept ENTIRELY separate from ~/.claude so the normal
      # Anthropic-backed `claude` is never affected. The key is cached in this
      # wrapper's own dir; we never touch ~/.claude/settings.json.
      keyfile="$HOME/.claude-deepseek/key"
      mkdir -p "$HOME/.claude-deepseek"

      # Priority:
      #   1. ANTHROPIC_AUTH_TOKEN already in this process's env.
      #   2. 1Password (works from a terminal) — refreshes the cache on success.
      #   3. The cached key file (the fallback when launched from a GUI like
      #      nimbalyst, where the 1Password CLI desktop integration is
      #      unreachable). Run dclaude once from a terminal to seed it.
      if [ -n "''${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        key="$ANTHROPIC_AUTH_TOKEN"
      elif key="$(op read "op://Personal/DeepSeek API/credential" 2>/dev/null)" && [ -n "$key" ]; then
        ( umask 077; printf '%s' "$key" > "$keyfile" )
      elif [ -s "$keyfile" ]; then
        key="$(cat "$keyfile")"
      else
        echo "dclaude: no DeepSeek key available. Run 'dclaude' once from a terminal (with 1Password unlocked) to cache the key, or write it to $keyfile." >&2
        exit 1
      fi

      # OpenRouter key for the vision proxy (image descriptions). The cached
      # keyfile is shared with the anthropic-proxy-openrouter service.
      # Non-fatal: missing key only disables image descriptions.
      orkey=""
      if [ -n "''${OPENROUTER_API_KEY:-}" ]; then
        orkey="$OPENROUTER_API_KEY"
      elif orkey="$(op read "op://Personal/OpenRouter API/credential" 2>/dev/null)" && [ -n "$orkey" ]; then
        ( umask 077; printf '%s' "$orkey" > "$HOME/.claude-openrouter/key" )
      elif [ -s "$HOME/.claude-openrouter/key" ]; then
        orkey="$(cat "$HOME/.claude-openrouter/key")"
      else
        echo "dclaude: warning: no OpenRouter key available — image descriptions will fail. Run once from a terminal with 1Password unlocked, or write the key to $HOME/.claude-openrouter/key." >&2
      fi

      unset ANTHROPIC_API_KEY
      export ANTHROPIC_AUTH_TOKEN="$key"
      export ANTHROPIC_MODEL="deepseek-v4-flash"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-flash"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
      export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
      export CLAUDE_CODE_EFFORT_LEVEL="max"
      export CLAUDE_CONFIG_DIR="$HOME/.claude-deepseek"
      mkdir -p "$CLAUDE_CONFIG_DIR"

      # SKILLS: shared with the main ~/.claude instance via symlink. Skills
      # store no absolute paths, so this is safe and stays in sync.
      [ -e "$HOME/.claude/skills" ] && ln -sfn "$HOME/.claude/skills" "$CLAUDE_CONFIG_DIR/skills" || true

      # PLUGINS: can NOT be symlinked — each marketplace records an absolute
      # installLocation that must resolve inside *this* config dir, so a shared
      # symlink fails validation ("corrupted installLocation"). Seed an
      # independent copy with the paths rewritten, only when missing (or when an
      # old broken symlink is present). Tolerant of a missing source.
      if [ -d "$HOME/.claude/plugins" ] && { [ -L "$CLAUDE_CONFIG_DIR/plugins" ] || [ ! -e "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json" ]; }; then
        rm -rf "$CLAUDE_CONFIG_DIR/plugins"
        cp -r "$HOME/.claude/plugins" "$CLAUDE_CONFIG_DIR/plugins" || true
        for f in "$CLAUDE_CONFIG_DIR"/plugins/*.json; do
          [ -f "$f" ] && sed -i "s|$HOME/.claude/plugins|$CLAUDE_CONFIG_DIR/plugins|g" "$f" || true
        done
      fi

      # codegraph MCP server (idempotent — only added if not already present).
      grep -q '"codegraph"' "$CLAUDE_CONFIG_DIR/.claude.json" 2>/dev/null \
        || claude mcp add codegraph --scope user -- codegraph serve --mcp >/dev/null 2>&1 || true

      # Vision proxy (pkgs/glm-vision): rewrites image blocks to text
      # descriptions before they reach DeepSeek, which is text-only. Main
      # upstream stays DeepSeek-direct; descriptions are done by a cheap
      # vision model on OpenRouter (KIMI_VISION_*). Degrades to text-only
      # dclaude if the proxy fails to start.
      logfile="$CLAUDE_CONFIG_DIR/glm-vision.log"
      UPSTREAM_BASE_URL="https://api.deepseek.com/anthropic" \
      ANTHROPIC_AUTH_TOKEN="$key" \
      KIMI_VISION_BASE_URL="https://openrouter.ai/api" \
      KIMI_VISION_AUTH_TOKEN="$orkey" \
      KIMI_VISION_MODEL="qwen/qwen3-vl-32b-instruct" \
      KIMI_VISION_PROXY_PROMPT="Describe this image in detail and accurately: all visible text, UI elements, layout, colors, and anything else a text-only assistant needs to understand it." \
      KIMI_PROXY_PORT="8788" \
      ${pkgs.callPackage ../../pkgs/glm-vision { }}/bin/glm-vision-proxy >>"$logfile" 2>&1 &
      proxy_pid=$!
      trap 'kill $proxy_pid 2>/dev/null || true' EXIT INT TERM

      for _ in $(seq 1 50); do
        if curl -sf -o /dev/null "http://127.0.0.1:8788/"; then
          proxy_ready=1
          break
        fi
        sleep 0.2
      done
      if [ -z "''${proxy_ready:-}" ]; then
        echo "dclaude: glm-vision proxy failed to start (see $logfile) — continuing without vision." >&2
        kill "$proxy_pid" 2>/dev/null || true
        trap - EXIT INT TERM
      fi

      if [ -n "''${proxy_ready:-}" ]; then
        export ANTHROPIC_BASE_URL="http://127.0.0.1:8788"
      else
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
      fi

      claude "$@"
    '')

    # Separate Claude Code instance for a work Anthropic account, logged in
    # independently of the personal `claude`. Plain Anthropic backend (no API
    # key juggling, no proxy) — credentials live entirely under
    # CLAUDE_CONFIG_DIR (~/.claude-work/.credentials.json, no OS keychain
    # involved on Linux), so this is fully isolated from ~/.claude. Run
    # `wclaude` once and `/login` with the work account; after that it just
    # works like `claude` does for the personal account.
    (pkgs.writeShellScriptBin "wclaude" ''
      #!/usr/bin/env bash
      set -euo pipefail

      export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
      mkdir -p "$CLAUDE_CONFIG_DIR"

      # SKILLS: shared with the main ~/.claude instance via symlink. Skills
      # store no absolute paths, so this is safe and stays in sync.
      [ -e "$HOME/.claude/skills" ] && ln -sfn "$HOME/.claude/skills" "$CLAUDE_CONFIG_DIR/skills" || true

      # PLUGINS: can NOT be symlinked — each marketplace records an absolute
      # installLocation that must resolve inside *this* config dir, so a shared
      # symlink fails validation ("corrupted installLocation"). Seed an
      # independent copy with the paths rewritten, only when missing (or when an
      # old broken symlink is present). Tolerant of a missing source.
      if [ -d "$HOME/.claude/plugins" ] && { [ -L "$CLAUDE_CONFIG_DIR/plugins" ] || [ ! -e "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json" ]; }; then
        rm -rf "$CLAUDE_CONFIG_DIR/plugins"
        cp -r "$HOME/.claude/plugins" "$CLAUDE_CONFIG_DIR/plugins" || true
        for f in "$CLAUDE_CONFIG_DIR"/plugins/*.json; do
          [ -f "$f" ] && sed -i "s|$HOME/.claude/plugins|$CLAUDE_CONFIG_DIR/plugins|g" "$f" || true
        done
      fi

      # codegraph MCP server (idempotent — only added if not already present).
      grep -q '"codegraph"' "$CLAUDE_CONFIG_DIR/.claude.json" 2>/dev/null \
        || claude mcp add codegraph --scope user -- codegraph serve --mcp >/dev/null 2>&1 || true

      exec claude "$@"
    '')

  ]
  ++ lib.optionals (!isWorkHost) [
    # ═══════════════════════════════════════════════════════════════════════════
    # OPENROUTER-BACKED CLAUDE CODE (excluded on work hosts)
    # These need the local anthropic-proxy user service, which isn't run on
    # work hosts — see modules/home/services.nix.
    # ═══════════════════════════════════════════════════════════════════════════

    # Separate Claude Code instance backed by OpenRouter, routed through our
    # own local anthropic-proxy (pkgs/anthropic-proxy) instead of OpenRouter's
    # native Anthropic Skin endpoint directly. The Skin doesn't expose
    # OpenRouter's `provider` routing controls to Claude Code at all — no
    # `only`, no quantization filter, nothing — which is how we ended up
    # silently routed to a stale fp4 rehost once and a 10 tps/1.8s-latency
    # provider another time. Our proxy fixes that: it hard-excludes anything
    # below fp8 quantization, and hard-excludes (once it has enough of its
    # own observations) any provider it has personally measured running
    # slower than DeepSeek's own published numbers — see
    # pkgs/anthropic-proxy/src/routing.rs for the full design.
    #
    # The proxy runs as a persistent systemd --user service (see
    # modules/home/services.nix), NOT spawned fresh per launch: its learned
    # per-provider performance data lives in process memory, and starting a
    # new proxy per session would throw that away every time. This wrapper
    # just makes sure the service is up and points Claude Code at it.
    #
    # Session-based sticky routing (so a whole Claude Code session's cache
    # hits stay on one provider) needs no client-side header injection here:
    # the proxy forwards Claude Code's own `metadata.user_id` — already
    # stable for one Claude Code session — as OpenRouter's session_id.
    (pkgs.writeShellScriptBin "orclaude" ''
      #!/usr/bin/env bash
      set -euo pipefail

      proxy_url="http://127.0.0.1:8317"

      systemctl --user start anthropic-proxy-openrouter.service 2>/dev/null || true

      # Wait for the proxy to actually be answering — covers both a cold
      # start and the "1Password was locked at boot" retry loop the service
      # itself handles (Restart=on-failure).
      ready=""
      for _ in $(seq 1 30); do
        if curl -fsS -m 1 "$proxy_url/health" >/dev/null 2>&1; then
          ready=1
          break
        fi
        sleep 1
      done
      if [ -z "$ready" ]; then
        echo "orclaude: anthropic-proxy-openrouter.service isn't answering after 30s." >&2
        echo "  Check: systemctl --user status anthropic-proxy-openrouter.service" >&2
        echo "  Most likely cause: 1Password was locked when the service last tried to start — unlock it, then:" >&2
        echo "  systemctl --user restart anthropic-proxy-openrouter.service" >&2
        exit 1
      fi

      unset ANTHROPIC_API_KEY
      export ANTHROPIC_BASE_URL="$proxy_url"
      # The proxy holds the real OpenRouter key server-side and ignores
      # this — Claude Code just needs a non-empty token to make requests.
      export ANTHROPIC_AUTH_TOKEN="orclaude-local"
      # Pinned to the dated GA slug, NOT the floating "deepseek/deepseek-v4-flash"
      # alias: the floating tag let OpenRouter route us to a provider (Alibaba)
      # still serving the stale April preview build (-0423) instead of the
      # July 31 official release (-0731), which DeepSeek's own benchmarks show
      # meaningfully outperforms the preview on agentic/coding tasks. Update
      # this date by hand when DeepSeek ships the next official V4-Flash build
      # (and the PROVIDER_TRACKING_MODEL in modules/home/services.nix to match).
      export ANTHROPIC_MODEL="deepseek/deepseek-v4-flash-20260731"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek/deepseek-v4-flash-20260731"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek/deepseek-v4-flash-20260731"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek/deepseek-v4-flash-20260731"
      export CLAUDE_CODE_SUBAGENT_MODEL="deepseek/deepseek-v4-flash-20260731"
      export CLAUDE_CODE_EFFORT_LEVEL="max"
      export CLAUDE_CONFIG_DIR="$HOME/.claude-openrouter"
      mkdir -p "$CLAUDE_CONFIG_DIR"

      # SKILLS: shared with the main ~/.claude instance via symlink. Skills
      # store no absolute paths, so this is safe and stays in sync.
      [ -e "$HOME/.claude/skills" ] && ln -sfn "$HOME/.claude/skills" "$CLAUDE_CONFIG_DIR/skills" || true

      # PLUGINS: can NOT be symlinked — each marketplace records an absolute
      # installLocation that must resolve inside *this* config dir, so a shared
      # symlink fails validation ("corrupted installLocation"). Seed an
      # independent copy with the paths rewritten, only when missing (or when an
      # old broken symlink is present). Tolerant of a missing source.
      if [ -d "$HOME/.claude/plugins" ] && { [ -L "$CLAUDE_CONFIG_DIR/plugins" ] || [ ! -e "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json" ]; }; then
        rm -rf "$CLAUDE_CONFIG_DIR/plugins"
        cp -r "$HOME/.claude/plugins" "$CLAUDE_CONFIG_DIR/plugins" || true
        for f in "$CLAUDE_CONFIG_DIR"/plugins/*.json; do
          [ -f "$f" ] && sed -i "s|$HOME/.claude/plugins|$CLAUDE_CONFIG_DIR/plugins|g" "$f" || true
        done
      fi

      # codegraph MCP server (idempotent — only added if not already present).
      grep -q '"codegraph"' "$CLAUDE_CONFIG_DIR/.claude.json" 2>/dev/null \
        || claude mcp add codegraph --scope user -- codegraph serve --mcp >/dev/null 2>&1 || true

      exec claude "$@"
    '')

    # Companion to `orclaude`: shows which provider/model actually served the
    # most recent turn in the current OpenRouter-backed session, plus its
    # cache-hit rate, cost, and latency. Reads the generation id straight out
    # of Claude Code's own transcript — an OpenRouter-native `gen-...` id,
    # passed through unchanged by the Anthropic Skin — and looks it up via
    # OpenRouter's generation endpoint. No proxy, no daemon, just a lookup.
    # Per https://openrouter.ai/docs/api/api-reference/generations/get-generation
    (pkgs.writeShellScriptBin "orclaude-status" ''
      #!/usr/bin/env bash
      set -euo pipefail

      keyfile="$HOME/.claude-openrouter/key"
      if [ -n "''${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        key="$ANTHROPIC_AUTH_TOKEN"
      elif [ -s "$keyfile" ]; then
        key="$(cat "$keyfile")"
      else
        echo "orclaude-status: no OpenRouter key cached. Run 'orclaude' once first." >&2
        exit 1
      fi

      transcript="$(find "$HOME/.claude-openrouter/projects" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n1 | cut -d' ' -f2-)"
      if [ -z "$transcript" ]; then
        echo "orclaude-status: no orclaude session transcript found yet. Send a message in orclaude first." >&2
        exit 1
      fi

      gen_id="$(grep -o '"id":"gen-[^"]*"' "$transcript" | tail -n1 | cut -d'"' -f4)"
      if [ -z "$gen_id" ]; then
        echo "orclaude-status: no OpenRouter generation id found in the latest transcript ($transcript)." >&2
        exit 1
      fi

      curl -s "https://openrouter.ai/api/v1/generation?id=$gen_id" -H "Authorization: Bearer $key" \
        | ${pkgs.jq}/bin/jq -r '
        .data |
        "provider:   \(.provider_name)
      model:      \(.model)
      cache hit:  \(.native_tokens_cached) / \(.native_tokens_prompt) tokens (\((.native_tokens_cached / .native_tokens_prompt * 100) | floor)%)
      cost:       $\(.total_cost)
      latency:    \(.latency)ms"
      '
    '')
  ]
  ++ [
    # claude-desktop on NixOS + NVIDIA Blackwell open driver:
    # Use the bundled Electron (currently 41.6.1) with
    # --js-flags=--no-memory-protection-keys to work around the V8 PKU SEGV
    # on kernel 6.18+. Previously we swapped in electron_39 from nixpkgs,
    # but that's now EOL.
    # path-translator.js patch: app wraps path.join/resolve and throws on
    # non-string segments passed by getDefaultPermissionMode / Cowork code.
    # Coerce non-string segments before calling the original join/resolve.
    (
      let
        claudePkg = inputs.claude-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
        patchedAsar =
          pkgs.runCommand "claude-desktop-app-patched.asar"
            {
              nativeBuildInputs = [ pkgs.asar ];
            }
            ''
              mkdir asar-src
              asar extract ${claudePkg}/lib/claude-desktop/app.asar asar-src
              # 1. path.join/resolve: coerce non-string segments so Cowork's
              #    getDefaultPermissionMode path doesn't throw on object args.
              substituteInPlace asar-src/.vite/build/path-translator.js \
                --replace-fail \
                  'translatePath(_origJoin(...segments))' \
                  'translatePath(_origJoin(...segments.map(s => typeof s === "string" ? s : s == null ? "" : String(s))))' \
                --replace-fail \
                  'translatePath(_origResolve(...segments))' \
                  'translatePath(_origResolve(...segments.map(s => typeof s === "string" ? s : s == null ? "" : String(s))))'
              # 2. claude-swift: translate ALL string env values on spawn, not just
              #    PATH. Otherwise CLAUDE_CONFIG_DIR=/sessions/... is passed through
              #    verbatim to claude-code, which silently exits on the unreachable path.
              substituteInPlace asar-src/node_modules/@ant/claude-swift/index.js \
                --replace-fail \
                  "    let resolvedEnv = env;
                  if (env && typeof env.PATH === 'string') {
                    resolvedEnv = {
                      ...env,
                      PATH: env.PATH.split(':').map(p => translatePath(p)).join(':'),
                    };
                  }" \
                  "    let resolvedEnv = env;
                  if (env) {
                    resolvedEnv = {};
                    for (const [k, v] of Object.entries(env)) {
                      if (typeof v !== 'string') { resolvedEnv[k] = v; continue; }
                      if (k === 'PATH') {
                        resolvedEnv[k] = v.split(':').map(p => translatePath(p)).join(':');
                      } else {
                        resolvedEnv[k] = translatePath(v);
                      }
                    }
                  }"
              asar pack asar-src $out
            '';
      in
      pkgs.symlinkJoin {
        name = "claude-desktop-nixos";
        paths = [ claudePkg ];
        postBuild = ''
          rm $out/bin/claude-desktop
          cp ${claudePkg}/bin/claude-desktop $out/bin/claude-desktop
          chmod +w $out/bin/claude-desktop
          substituteInPlace $out/bin/claude-desktop \
            --replace-fail \
              '${claudePkg}/lib/claude-desktop/app.asar' \
              '${patchedAsar}' \
            --replace-fail \
              '"$(dirname "$ASAR")/electron/electron"' \
              '"${claudePkg}/lib/electron/electron"' \
            --replace-fail \
              'exec "$ELECTRON" --no-sandbox "$ASAR" "$@"' \
              'exec "$ELECTRON" --no-sandbox --js-flags=--no-memory-protection-keys "$ASAR" "$@"' \
            --replace-fail \
              'COWORK_BACKEND="''${COWORK_BACKEND:-bubblewrap}"' \
              'COWORK_BACKEND="''${COWORK_BACKEND:-host}"'
        '';
      }
    )
    pkgs.bubblewrap # Sandboxing for claude-desktop Cowork backend

  ]
  ++ lib.optionals (!isWorkHost) [
    # ═══════════════════════════════════════════════════════════════════════════
    # GAMING & ENTERTAINMENT (excluded on work hosts)
    # ═══════════════════════════════════════════════════════════════════════════
    (pkgs.callPackage ../../curseforge.nix { })
    pkgs.prismlauncher
    # Lutris wrapped to prevent glib module conflicts with Proton
    (pkgs.symlinkJoin {
      name = "lutris-wrapped";
      paths = [ pkgs.lutris ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/lutris --set GIO_MODULE_DIR ""
      '';
    })
    (pkgs.retroarch.withCores (
      cores: with cores; [
        mupen64plus # Nintendo 64
        parallel-n64 # Nintendo 64 (ParaLLEl - better accuracy, Vulkan)
      ]
    ))
    pkgs.eden # Switch emulator (Yuzu/Sudachi fork)
    pkgs.mpv
    pkgs.qbittorrent
    pkgs.bolt-launcher # OSRS launcher (RuneLite, HDOS, official client)
    pkgs.edmarketconnector # Elite Dangerous market data uploader
    # X11 tools removed: running Wayland, these only work under XWayland
    pkgs.wineWow64Packages.stagingFull
    pkgs.winetricks
  ]
  ++ [
    # Work tools (Sikt/Zino)
    (pkgs.callPackage ../../curitz.nix { }) # ncurses Zino client, reads ~/.ritz.tcl (needs EduVPN)
    pkgs.wireguard-tools
    pkgs.kubectl
    pkgs.k9s
    pkgs.sops

  ]
  ++ lib.optionals (!isWorkHost) [
    # ═══════════════════════════════════════════════════════════════════════════
    # PERSONAL PACKAGES (excluded on work hosts)
    # ═══════════════════════════════════════════════════════════════════════════

    # 3D Printing
    # OrcaSlicer wrapped with zink to fix NVIDIA Wayland preview rendering
    (pkgs.symlinkJoin {
      name = "orca-slicer-wrapped";
      paths = [ pkgs.orca-slicer ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/orca-slicer \
          --set __GLX_VENDOR_LIBRARY_NAME mesa \
          --set __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
          --set MESA_LOADER_DRIVER_OVERRIDE zink \
          --set GALLIUM_DRIVER zink \
          --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      '';
    })

    # Distributed computing
    # BOINC wrapped so all binaries (boinc, boinc_client, boincmgr, boinccmd)
    # see /run/opengl-driver/lib in LD_LIBRARY_PATH. Without this, GPU detection
    # fails ("NVIDIA: libcuda.so: cannot open shared object file") unless BOINC
    # happens to be launched from an environment that already set LD_LIBRARY_PATH.
    (pkgs.symlinkJoin {
      name = "boinc-wrapped";
      paths = [ pkgs.boinc ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for prog in boinc boinc_client boincmgr boinccmd boincscr; do
          if [ -f "$out/bin/$prog" ]; then
            wrapProgram "$out/bin/$prog" \
              --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
          fi
        done
      '';
    })
    pkgs.boinctui # BOINC terminal UI
    pkgs.fahclient # Folding@home client
    (import ../../fresco.nix { inherit pkgs; }) # Modern BOINC manager GUI (Tauri)

    # BOINC Manager wrapper: uses ~/boinc as data directory, starts in advanced mode.
    # GDK_BACKEND=x11 forces XWayland to avoid wxWidgets/Pango font crash on native Wayland.
    # (LD_LIBRARY_PATH is now baked into the BOINC binaries above, no longer needed here.)
    (pkgs.writeShellScriptBin "boinc-manager" ''
      export GDK_BACKEND=x11
      exec boincmgr -a -d "$HOME/boinc" "$@"
    '')

    # Cryptocurrency
    pkgs.gridcoin-research # Gridcoin wallet
    # Smart launcher: uses ~/games/GridCoin/GridCoinResearch as data dir when present,
    # falls back to upstream default (~/.GridcoinResearch/) otherwise.
    (pkgs.writeShellScriptBin "gridcoin-wallet" ''
      DATADIR="$HOME/games/GridCoin/GridCoinResearch"
      if [ -d "$DATADIR" ]; then
        exec ${pkgs.gridcoin-research}/bin/gridcoinresearch -datadir="$DATADIR" "$@"
      else
        exec ${pkgs.gridcoin-research}/bin/gridcoinresearch "$@"
      fi
    '')
    pkgs.sparrow # Sparrow Bitcoin wallet
    pkgs.ledger-live-desktop # Ledger hardware wallet

    # Proton-GE management (auto-update latest version)
    pkgs.protonup-ng
  ]
  ++ [
    # Flake-based rebuild script
    (pkgs.writeShellScriptBin "nixos-rebuild-flake" ''
      #!/usr/bin/env bash
      set -e

      CONFIG_DIR="/home/gjermund/nix-config"
      SILENT=false
      FORCE_BOOT=false

      # Parse arguments
      ARGS=()
      for arg in "$@"; do
        case $arg in
          -s|--silent)
            SILENT=true
            ;;
          -b|--boot)
            FORCE_BOOT=true
            ;;
          *)
            ARGS+=("$arg")
            ;;
        esac
      done

      # Check if we're in a git repo
      if [ ! -d "$CONFIG_DIR/.git" ]; then
        echo "Error: $CONFIG_DIR is not a git repository"
        exit 1
      fi

      # Auto-update CurseForge version from Arch AUR (skip in silent mode)
      if [ "$SILENT" = false ]; then
        echo "Checking for CurseForge updates..."
        NIX_FILE="$CONFIG_DIR/curseforge.nix"
        if [ -f "$NIX_FILE" ]; then
          AUR_VERSION=$(${pkgs.curl}/bin/curl -sf "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=curseforge" | grep "^pkgver=" | cut -d= -f2 || true)
          if [ -n "$AUR_VERSION" ]; then
            VERSION="''${AUR_VERSION//_/-}"
            CURRENT=$(grep 'version = "' "$NIX_FILE" | ${pkgs.gnused}/bin/sed 's/.*version = "\(.*\)";/\1/')
            if [ "$VERSION" != "$CURRENT" ]; then
              echo "CurseForge update available: $CURRENT -> $VERSION"
              URL="https://curseforge.overwolf.com/electron/linux/CurseForge_''${VERSION}_amd64.deb"
              HASH=$(nix-prefetch-url "$URL" 2>/dev/null || true)
              if [ -n "$HASH" ]; then
                ${pkgs.gnused}/bin/sed -i "s/version = \".*\";/version = \"$VERSION\";/" "$NIX_FILE"
                ${pkgs.gnused}/bin/sed -i "s/sha256 = \".*\";/sha256 = \"$HASH\";/" "$NIX_FILE"
                echo "CurseForge updated to $VERSION"
              fi
            else
              echo "CurseForge is up to date ($VERSION)"
            fi
          fi
        fi
      fi

      # Detect hostname to select the correct flake output
      HOSTNAME=$(hostname)

      # Check if kernel, systemd, or NVIDIA driver version changed. These can't
      # be applied to a live system: kernel/systemd risk a D-Bus restart / hang,
      # and an NVIDIA driver bump leaves the loaded kernel module mismatched
      # against the new userspace libs until reboot (breaks CUDA, the container
      # CDI generator, and can crash the session). All require 'boot' + reboot.
      USE_BOOT=false
      # With --boot the mode is already decided; skip the change detection
      # (it only exists to prompt for boot mode when kernel/systemd/nvidia
      # change, which a forced boot makes moot).
      if [ "$SILENT" = false ] && [ "$FORCE_BOOT" = false ]; then
        echo "Checking for kernel/systemd/nvidia changes..."
        CURRENT_KERNEL=$(uname -r)
        CURRENT_SYSTEMD=$(systemctl --version 2>/dev/null | head -1 | ${pkgs.gnugrep}/bin/grep -oP '\(\K[^)]+' || systemctl --version 2>/dev/null | head -1 | ${pkgs.gawk}/bin/awk '{print $2}')

        # Use nix eval to query versions without building
        NEW_KERNEL=$(nix eval "$CONFIG_DIR#nixosConfigurations.$HOSTNAME.config.boot.kernelPackages.kernel.version" --raw 2>/dev/null || true)
        NEW_SYSTEMD=$(nix eval "$CONFIG_DIR#nixosConfigurations.$HOSTNAME.config.systemd.package.version" --raw 2>/dev/null || true)

        CHANGES=""
        if [ -n "$NEW_KERNEL" ] && [ "$NEW_KERNEL" != "$CURRENT_KERNEL" ]; then
          CHANGES="kernel: $CURRENT_KERNEL -> $NEW_KERNEL"
        fi
        if [ -n "$NEW_SYSTEMD" ] && [ "$NEW_SYSTEMD" != "$CURRENT_SYSTEMD" ]; then
          [ -n "$CHANGES" ] && CHANGES="$CHANGES, "
          CHANGES="''${CHANGES}systemd: $CURRENT_SYSTEMD -> $NEW_SYSTEMD"
        fi

        # NVIDIA driver: only relevant when the module is currently loaded
        # (skips Intel-only hosts, where hardware.nvidia isn't configured).
        if [ -r /sys/module/nvidia/version ]; then
          CURRENT_NVIDIA=$(cat /sys/module/nvidia/version 2>/dev/null || true)
          NEW_NVIDIA=$(nix eval "$CONFIG_DIR#nixosConfigurations.$HOSTNAME.config.hardware.nvidia.package.version" --raw 2>/dev/null || true)
          if [ -n "$NEW_NVIDIA" ] && [ "$NEW_NVIDIA" != "$CURRENT_NVIDIA" ]; then
            [ -n "$CHANGES" ] && CHANGES="$CHANGES, "
            CHANGES="''${CHANGES}nvidia: $CURRENT_NVIDIA -> $NEW_NVIDIA"
          fi
        fi

        if [ -n "$CHANGES" ]; then
          echo ""
          echo "⚠  Version changes detected: $CHANGES"
          echo "   These can't be applied live (D-Bus restart / driver mismatch)."
          echo ""
          read -rp "Use 'boot' instead of 'switch'? (reboot required) [Y/n] " REPLY || REPLY="n"
          case "''${REPLY:-Y}" in
            [nN]*) USE_BOOT=false ;;
            *) USE_BOOT=true ;;
          esac
        else
          echo "No kernel/systemd/nvidia changes detected, safe to switch live."
        fi
      fi

      # Forced boot mode: override whatever the detection decided.
      if [ "$FORCE_BOOT" = true ]; then
        USE_BOOT=true
      fi

      # Keep zram swap active during the build — switching it off here removes
      # the memory-overflow safety net during memory-heavy nix builds and can
      # lock up the machine. NixOS's systemd-zram-setup@zram0 service handles
      # reconfiguration itself on the rare occasion zram settings change.

      # Run nh os switch/boot with flake
      if [ "$SILENT" = true ]; then
        if [ "$FORCE_BOOT" = true ]; then
          nh os boot -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
            echo "nh os boot failed"
            exit 1
          }
        else
          nh os switch -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
            echo "nh os switch failed"
            exit 1
          }
        fi
        # Silent mode: skip git operations, exit here
        exit 0
      elif [ "$USE_BOOT" = true ]; then
        echo "Running nh os boot for host '$HOSTNAME'..."
        nh os boot --ask -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
          echo "nh os boot failed, not committing changes"
          exit 1
        }
        echo ""
        echo "✓ New configuration set as boot default. Reboot to activate."
      else
        echo "Running nh os switch for host '$HOSTNAME'..."
        nh os switch --ask -H "$HOSTNAME" "$CONFIG_DIR" "''${ARGS[@]}" || {
          echo "nh os switch failed, not committing changes"
          exit 1
        }
      fi

      # Quickshell auto-reloads on config changes

      # If successful, commit and push as the regular user
      cd "$CONFIG_DIR"

      # Stage modifications and deletions of already-tracked files (always safe).
      git add -u

      # New (untracked) files are staged only after explicit confirmation, so a
      # stray file — an accidentally-created ~ dir, a dumped secret, an .env —
      # can never be silently committed and pushed again. Respects .gitignore.
      UNTRACKED=$(git ls-files --others --exclude-standard)
      if [ -n "$UNTRACKED" ]; then
        echo ""
        echo "⚠  New untracked files detected:"
        echo "$UNTRACKED" | ${pkgs.gnused}/bin/sed 's/^/     /'
        echo ""
        read -rp "Add these new files to the commit? [y/N] " ADD_NEW || ADD_NEW="N"
        case "''${ADD_NEW:-N}" in
          [yY]*) git add -A ;;
          *) echo "   Leaving new files unstaged (not committed)." ;;
        esac
      fi

      # Nothing staged? Then there's nothing to commit.
      if git diff --cached --quiet; then
        echo "No changes to commit"
        exit 0
      fi

      # Generate dynamic commit message based on changes
      CHANGED_FILES=$(git diff --cached --name-only)
      DIFF_STAT=$(git diff --cached --stat --stat-width=80 | tail -1)

      # Analyze the diff for meaningful changes
      DIFF_CONTENT=$(git diff --cached -U0)

      # Extract added packages (lines starting with + containing pkgs.)
      ADDED_PKGS=$(echo "$DIFF_CONTENT" | grep -E '^[+].*pkgs[.]' | grep -v '^[+][+][+]' | sed 's/.*pkgs[.]\([a-zA-Z0-9_-]*\).*/\1/' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

      # Extract removed packages
      REMOVED_PKGS=$(echo "$DIFF_CONTENT" | grep -E '^[-].*pkgs[.]' | grep -v '^[-][-][-]' | sed 's/.*pkgs[.]\([a-zA-Z0-9_-]*\).*/\1/' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

      # Build commit message
      COMMIT_MSG=""

      if [ -n "$ADDED_PKGS" ] && [ -n "$REMOVED_PKGS" ]; then
        COMMIT_MSG="Add $ADDED_PKGS; Remove $REMOVED_PKGS"
      elif [ -n "$ADDED_PKGS" ]; then
        COMMIT_MSG="Add $ADDED_PKGS"
      elif [ -n "$REMOVED_PKGS" ]; then
        COMMIT_MSG="Remove $REMOVED_PKGS"
      else
        # Check for config changes in specific files
        if echo "$CHANGED_FILES" | grep -qE "hyprland\.(conf|lua)"; then
          COMMIT_MSG="Update Hyprland config"
        elif echo "$CHANGED_FILES" | grep -q "alacritty"; then
          COMMIT_MSG="Update Alacritty config"
        elif echo "$CHANGED_FILES" | grep -q "waybar"; then
          COMMIT_MSG="Update Waybar config"
        elif echo "$CHANGED_FILES" | grep -q "configuration.nix"; then
          COMMIT_MSG="Update NixOS configuration"
        else
          COMMIT_MSG="Update config"
        fi
      fi

      # Add file count info
      FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
      if [ "$FILE_COUNT" -gt 1 ]; then
        COMMIT_MSG="$COMMIT_MSG ($FILE_COUNT files)"
      fi

      # Commit
      git commit -m "$COMMIT_MSG"
      echo "Changes committed: $COMMIT_MSG"

      # Push to remote (if configured)
      if git remote | grep -q .; then
        echo "Pushing to remote..."
        git push || echo "Warning: Push failed, but rebuild was successful"
      else
        echo "No remote configured, skipping push"
      fi
    '')
  ];
}
