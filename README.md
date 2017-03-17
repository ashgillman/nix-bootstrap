This repository contains a script that allows to bootstrap a single-user installation of (nix)[http://nixos.org/nix/]. It currently only targets RHEL6 based systems (CentOS 6, Scientific Linux 6).

This will place store in ```$HOME/nix/store``` instead of ```/nix/store```. The drawback here is that you then will not be able to use the official NixOS binary cache since store paths are not rellocable.
