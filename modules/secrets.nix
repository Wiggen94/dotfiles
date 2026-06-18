# sops-nix secrets — decrypted at activation with the age key in ~/.ssh/age-key.txt
#
# Edit secrets with:  sops secrets/secrets.yaml   (from repo root)

{ ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/gjermund/.ssh/age-key.txt";

    # curitz Zino config — placed at ~/.ritz.tcl (the default path curitz reads).
    # sops-nix symlinks this path to the decrypted secret; needs EduVPN to reach hugin.
    secrets.ritz_tcl = {
      path = "/home/gjermund/.ritz.tcl";
      owner = "gjermund";
      group = "users";
      mode = "0600";
    };
  };
}
