# Work container — import this in your host's configuration
#
# Provides an isolated NixOS container with WireGuard VPN,
# Vivaldi browser, and your zsh config.

{ config, lib, pkgs, inputs, ... }:

{
  # NAT for container internet access
  # Use wildcard to handle both wired and wireless interfaces
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = lib.mkDefault "wlp0s20f3";
  };

  containers.work = {
    autoStart = false;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";

    bindMounts = {
      # Wayland socket — at /var/wayland-socket because systemd mounts
      # fresh tmpfs on /run inside the container, which would mask it
      "/var/wayland-socket" = {
        hostPath = "/run/user/1000";
        isReadOnly = false;
      };
      # Work directory — persists across container restarts
      "/home/gjermund/work" = {
        hostPath = "/home/gjermund/work";
        isReadOnly = false;
      };
      # WireGuard config from host
      "/etc/wireguard/work.conf" = {
        hostPath = "/home/gjermund/.config/wireguard/work.conf";
        isReadOnly = true;
      };
      # Age key for sops decryption
      "/run/secrets/age-key.txt" = {
        hostPath = "/home/gjermund/.ssh/age-key.txt";
        isReadOnly = true;
      };
      # Encrypted secrets file
      "/run/secrets/secrets.yaml" = {
        hostPath = "/home/gjermund/nix-config/work-container/secrets.yaml";
        isReadOnly = true;
      };
      # GPU access for Vivaldi and Alacritty
      "/dev/dri" = {
        hostPath = "/dev/dri";
        isReadOnly = false;
      };
    };

    config = { ... }: {
      imports = [
        (import ./container-os.nix)
        inputs.home-manager.nixosModules.home-manager
      ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.gjermund = import ./container-home.nix;
      };
    };
  };

  # Grant container CAP_NET_ADMIN for WireGuard + GPU device access
  systemd.services."container@work" = {
    preStart = lib.mkAfter ''
      mkdir -p /var/lib/nixos-containers/work/var/wayland-socket
      chmod 700 /var/lib/nixos-containers/work/var/wayland-socket
      chown 1000:100 /var/lib/nixos-containers/work/var/wayland-socket
      mkdir -p /var/lib/nixos-containers/work/home/gjermund
    '';
    serviceConfig = {
      DeviceAllow = [ "/dev/net/tun rw" "/dev/dri/renderD128 rw" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    };
  };

  # Allow user to manage the container without password
  security.sudo.extraRules = [{
    users = [ "gjermund" ];
    commands = [
      { command = "/run/current-system/sw/bin/nixos-container"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/machinectl";      options = [ "NOPASSWD" ]; }
    ];
  }];
}
