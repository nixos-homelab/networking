{
  description = "NixOS Homelab Networking Workloads";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-mongodb-pin.url = "github:NixOS/nixpkgs/9b696460ac78b5ccfc17c854d8c976f20456e943";
    flake-parts.url = "github:hercules-ci/flake-parts";
    kube-generators.url = "github:farcaller/nix-kube-generators";
    kubetree = {
      url = "github:andsens/nix-kubetree";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
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
      inputs.kubetree.follows = "kubetree";
      inputs.kube-generators.follows = "kube-generators";
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
          };
          nixosModules = {
            cilium = importApply ./nix/modules/cilium { inherit self inputs; };
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
          let
            options-docs = inputs.docs.lib.docs.options {
              inherit pkgs;
              modules = lib.attrValues self.nixosModules;
              repoPath = toString self;
              repoLinkPrefix = "https://github.com/nixos-homelab/networking/blob/main";
            };
          in
          {
            apps.update-docs.program = inputs.docs.lib.docs.updateRepo {
              inherit pkgs;
              paths."docs/options.md" = options-docs.optionsCommonMark;
            };
            packages.options-docs = options-docs.optionsCommonMark;
          };
      }
    );
}
