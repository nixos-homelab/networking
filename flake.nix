{
  description = "NixOS Homelab Networking Workloads";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-mongodb-pin.url = "github:NixOS/nixpkgs/9b696460ac78b5ccfc17c854d8c976f20456e943";
    flake-parts.url = "github:hercules-ci/flake-parts";
    kube-generators.url = "github:farcaller/nix-kube-generators";
    setup-secrets = {
      url = "github:andsens/nixos-setup-secrets";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    homelab-shared = {
      url = "github:nixos-homelab/shared";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kube-generators.follows = "kube-generators";
      inputs.homelab-monitoring.follows = "homelab-monitoring";
    };
    homelab-monitoring = {
      url = "github:nixos-homelab/monitoring";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kube-generators.follows = "kube-generators";
      inputs.homelab-shared.follows = "homelab-shared";
      inputs.docs.follows = "docs";
    };
    nixhelm = {
      url = "github:nix-community/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    docs = {
      url = "github:andsens/nix-docs";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
  outputs =
    {
      systems,
      flake-parts,
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        self,
        inputs,
        lib,
        ...
      }:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        systems = import systems;
        flake = {
          lib = {
            importsApply = map (path: importApply path { inherit self inputs; });
            toPorts = import ./nix/lib/to-ports.nix;
          };
          nixosModules = {
            cilium = importApply ./nix/modules/cilium { inherit self inputs; };
            cilium-crds = importApply ./nix/modules/cilium/crds.nix { inherit self inputs; };
            client-vpn = importApply ./nix/modules/client-vpn { inherit self inputs; };
            external-dns = importApply ./nix/modules/external-dns { inherit self inputs; };
            homepage = importApply ./nix/modules/homepage { inherit self inputs; };
            netutils = importApply ./nix/modules/netutils { inherit self inputs; };
            privacy-vpn = importApply ./nix/modules/privacy-vpn { inherit self inputs; };
            routed-ippool = importApply ./nix/modules/routed-ippool { inherit self inputs; };
            unifi = importApply ./nix/modules/unifi { inherit self inputs; };
          };
        };
        perSystem =
          { pkgs, lib, ... }:
          {
            # Dead Nix code. Pattern names stay: modules take { config, lib, pkgs, ... } whether they use them or not
            checks.deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
              deadnix --fail --no-lambda-pattern-names ${self}
              touch $out
            '';
            # Addresses from the documentation ranges, keys all zero
            checks.manifests = inputs.homelab-shared.lib.checks.manifests {
              inherit pkgs;
              modules = lib.attrValues self.nixosModules ++ [
                ./nix/tests/config.nix
                {
                  nixpkgs.config.allowUnfreePredicate =
                    pkg:
                    builtins.elem (lib.getName pkg) [
                      "unifi-controller"
                      "mongodb"
                    ];
                }
              ];
            };
            # The cluster on one node under the NixOS test driver, with a LAN host beside it (needs KVM)
            checks.cluster = import ./nix/tests/cluster.nix { inherit self inputs pkgs; };
            packages = {
              options-docs = inputs.docs.lib.docs.options {
                inherit pkgs;
                modules = lib.attrValues self.nixosModules;
                repoPath = toString self;
                repoLinkPrefix = "https://github.com/nixos-homelab/networking/blob/main";
                prefixGroups = {
                  cilium = [ "homelab.cilium" ];
                  client-vpn = [ "homelab.client-vpn" ];
                  external-dns = [ "homelab.external-dns" ];
                  netutils = [ "homelab.netutils" ];
                  privacy-vpn = [ "homelab.privacy-vpn" ];
                  routed-ippool = [ "homelab.routed-ippool" ];
                  unifi = [
                    "homelab.unifi"
                    "homelab.homepage.integrations.unifi"
                  ];
                  homepage = [ "homelab.homepage.sections" ];
                };
              };
              manual-docs = inputs.docs.lib.mkdocs.manual {
                inherit pkgs;
                rootDoc = ./README.md;
                pathMap = {
                  cilium = ./nix/modules/cilium/README.md;
                };
              };
            };
          };
      }
    );
}
