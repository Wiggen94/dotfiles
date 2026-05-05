# Desktop-specific configuration
# RTX 5070 Ti, 5120x1440@240Hz ultrawide, 4TB games drive
{ config, pkgs, lib, ... }:

let
  # CUDA-enabled llama.cpp build for RTX 5070 Ti
  llamaCpp = pkgs.llama-cpp.override { cudaSupport = true; };

  # Stable paths for GGUFs (copied out of the old ollama blobs)
  modelsDir   = "/var/lib/llama-cpp/models";
  llmModel    = "${modelsDir}/qwen3.6-abliterated-35b-a3b-q4_K.gguf";
  embedModel  = "${modelsDir}/nomic-embed-text.gguf";

  # Python interpreter with the deps the ollama-shim proxy needs.
  # The script itself lives at /home/gjermund/projects/hollow-agentOS/ollama_shim.py
  # so it's editable without a nix rebuild.
  ollamaShimPython = pkgs.python3.withPackages (ps: with ps; [
    fastapi uvicorn httpx
  ]);
  ollamaShimScript = "/home/gjermund/projects/hollow-agentOS/ollama_shim.py";
in
{
  # Always run at full speed (desktop is always plugged in)
  powerManagement.cpuFreqGovernor = "performance";

  # Desktop-only packages
  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "rustdesk";
      paths = [ rustdesk ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rustdesk --set GDK_BACKEND x11
      '';
    })  # Remote desktop - force X11 to fix keyboard grab on Wayland
    llamaCpp
  ];

  # Dedicated user for the llama-server services
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    home = modelsDir;
    createHome = false;
  };
  users.groups.llama-cpp = { };

  systemd.tmpfiles.rules = [
    "d ${modelsDir} 0755 llama-cpp llama-cpp - -"
  ];

  # Main LLM: Qwen3.6-abliterated-35B-A3B with MoE expert offload to CPU.
  # Dense layers + KV cache on GPU (16 GB VRAM), expert FFN weights on CPU.
  systemd.services.llama-main = {
    description = "llama-server (Qwen3.6-abliterated 35B-A3B, --cpu-moe)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      CUDA_VISIBLE_DEVICES = "0";
    };
    serviceConfig = {
      User = "llama-cpp";
      Group = "llama-cpp";
      ExecStart = lib.escapeShellArgs [
        "${llamaCpp}/bin/llama-server"
        "--model"          llmModel
        "--host"           "0.0.0.0"
        "--port"           "11500"
        "--ctx-size"       "8192"
        "--parallel"       "3"
        "--batch-size"     "2048"
        "--n-gpu-layers"   "999"
        "--n-cpu-moe"      "24"
        "--flash-attn"     "on"
        "--cache-type-k"   "q8_0"
        "--cache-type-v"   "q8_0"
        "--threads"        "11"
      ];
      Restart    = "always";
      RestartSec = "5s";
      LimitNOFILE = 65536;
    };
  };

  # Embeddings: nomic-embed-text in embedding-only mode on a separate port.
  systemd.services.llama-embed = {
    description = "llama-server (nomic-embed-text, --embeddings)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      CUDA_VISIBLE_DEVICES = "0";
    };
    serviceConfig = {
      User = "llama-cpp";
      Group = "llama-cpp";
      ExecStart = lib.escapeShellArgs [
        "${llamaCpp}/bin/llama-server"
        "--model"          embedModel
        "--host"           "0.0.0.0"
        "--port"           "11501"
        "--embeddings"
        "--ctx-size"       "8192"
        "--parallel"       "8"
        "--n-gpu-layers"   "999"
      ];
      Restart    = "always";
      RestartSec = "5s";
      LimitNOFILE = 65536;
    };
  };

  # Ollama-API translation proxy on port 11434.
  # Hollow-agentOS keeps calling host.docker.internal:11434/api/{generate,embeddings}
  # without modification — the shim translates each request to llama-server.
  systemd.services.ollama-shim = {
    description = "Ollama API → llama-server proxy";
    after = [ "llama-main.service" "llama-embed.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      OLLAMA_SHIM_LLM_URL   = "http://127.0.0.1:11500";
      OLLAMA_SHIM_EMBED_URL = "http://127.0.0.1:11501";
      OLLAMA_SHIM_HOST      = "0.0.0.0";
      OLLAMA_SHIM_PORT      = "11434";
    };
    serviceConfig = {
      # Run as gjermund so the script under /home/gjermund/... is reachable.
      # Pure network proxy, no privileged access needed.
      User = "gjermund";
      ExecStart = "${ollamaShimPython}/bin/python3 ${ollamaShimScript}";
      Restart    = "always";
      RestartSec = "5s";
    };
  };

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];

  # Mount 4TB games drive (desktop-only)
  fileSystems."/home/gjermund/games" = {
    device = "/dev/disk/by-uuid/1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" "nofail" ];
  };

  # Mount NFS share from NAS
  fileSystems."/zfs" = {
    device = "192.168.0.207:/share";
    fsType = "nfs";
    options = [ "defaults" "nofail" ];
  };

  # BEES deduplication for games drive (saves ~15-25GB on Proton prefixes)
  services.beesd.filesystems.games = {
    spec = "UUID=1c7bdee1-0f6d-4181-a13b-a8ee7237949a";
    hashTableSizeMB = 1024;  # 1GB hash table for 3.7TB drive
    extraOptions = [ "--loadavg-target" "2.0" ];
  };

  # Automated backups with rsync
  systemd.services.backup-home = {
    description = "Backup home directory to backup drive";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -aAXv --delete --exclude='.cache' --exclude='games' /home/gjermund/ /backup/home/";
    };
  };

  systemd.timers.backup-home = {
    description = "Daily home backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # Run if missed (e.g., system was off)
    };
  };
}
