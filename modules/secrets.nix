# sops-nix secrets — decrypted at activation with the age key in ~/.ssh/age-key.txt
#
# Edit secrets with:  sops secrets/secrets.yaml   (from repo root)
#
# Recipients (one age key per host) are listed in ../.sops.yaml. After adding
# a new host's key there, re-wrap the data key:
#   sops updatekeys secrets/secrets.yaml
#
# Imported on every host via flake.nix (alongside inputs.sops-nix.nixosModules.sops).
{ lib, hostName, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/gjermund/.ssh/age-key.txt";

    secrets =
      {
        # 9Router API key — bearer token for the routed default `claude` on
        # every host. modules/system/claude-router.nix exports it from
        # /run/secrets/9router_api_key in zsh init. Remote /v1 access to the
        # k3s 9Router instance requires it (only same-host calls skip the check).
        "9router_api_key" = {
          owner = "gjermund";
          group = "users";
          mode = "0400";
        };
      }
      # curitz Zino config at ~/.ritz.tcl — desktop only (needs EduVPN to
      # reach hugin; curitz isn't installed on the laptops).
      // lib.optionalAttrs (hostName == "desktop") {
        ritz_tcl = {
          path = "/home/gjermund/.ritz.tcl";
          owner = "gjermund";
          group = "users";
          mode = "0600";
        };
      };
  };
}
