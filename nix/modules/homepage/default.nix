{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  hllib = inputs.homelab-shared.lib;
in
{
  # https://github.com/hercules-ci/flake-parts/pull/251
  key = "${toString __curPos.file}#modules.nixos.homepage";
  options.homelab.homepage.sections.Networking = lib.mkOption {
    description = "Layout of the networking section";
    type = hllib.homepage.sectionOption;
  };
  imports = [ inputs.homelab-shared.nixosModules.homepage ];
}
