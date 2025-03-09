{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    python3
    openssh
    sshpass
    wireguard-tools
    netcat
  ];
}
