{
  description = "NixOS Homelab Networking Workloads";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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
            toPorts = import ./nix/lib/to-ports.nix;
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
          {
            # Addresses from the documentation ranges, keys all zero
            checks.manifests =
              let
                prefix6 = "2001:db8:0:1";
                key = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
              in
              inputs.homelab-shared.lib.checks.manifests {
                inherit pkgs;
                modules = lib.attrValues self.nixosModules ++ [
                  {
                    nixpkgs.config.allowUnfreePredicate =
                      pkg:
                      builtins.elem (lib.getName pkg) [
                        "unifi-controller"
                        "mongodb"
                      ];
                    kubetree.cilium.enable = true;
                    homelab = {
                      cluster = {
                        enableIPv6 = true;
                        podCidr6 = "${prefix6}:0:42::/96";
                        svcCidr6 = "${prefix6}:0:43::/112";
                      };
                      cilium = {
                        enable = true;
                        firewall.enable = true;
                        lbIpBlock6.cidr = "${prefix6}:0:44::/112";
                        cidr-groups = {
                          enable = true;
                          localLANCIDR4 = "192.0.2.0/24";
                          localLANCIDR6 = "2001:db8:0:2::/64";
                        };
                        network-policies.enable = true;
                      };
                      routed-ippool = {
                        enable = true;
                        lbIpBlock6.cidr = "${prefix6}:0:45::/112";
                      };
                      unifi = {
                        enable = true;
                        reservedIPs = [
                          "10.45.0.3"
                          "${prefix6}:0:45:0:3"
                        ];
                      };
                      client-vpn = {
                        enable = true;
                        groups.admins = {
                          allowEgress = [ "cluster" ];
                          reservedIPs = [
                            "10.45.0.2"
                            "${prefix6}:0:45:0:2"
                          ];
                          cidr4 = "10.16.189.0/24";
                          gatewayIPv4 = "10.16.189.1/24";
                          cidr6 = "fd00:1::/48";
                          gatewayIPv6 = "fd00:1::1/48";
                          gatewayPublicKey = key;
                          peers.laptop = {
                            enable = true;
                            ipv4 = "10.16.189.2/32";
                            ipv6 = "fd00:1::2/128";
                            publicKey = key;
                          };
                        };
                      };
                      privacy-vpn = {
                        enable = true;
                        gatewayAddress = "[2001:db8:0:3::10]:51820";
                        gatewayPublicKey = key;
                        clientIP4 = "10.2.0.2";
                        clientIP6 = "fd00:2::2";
                        gatewayIP4 = "10.2.0.1";
                        gatewayIP6 = "fd00:2::1";
                      };
                      homepage.enable = true;
                    };
                  }
                ];
              };
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
