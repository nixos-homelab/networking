{ ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.cilium.firewall;
  enable = config.homelab.cilium.enable && cfg.enable;
  fw = config.networking.firewall;
  # Host policies match sources, not devices: what reaches the host on its LAN device comes from the LAN (the gateway
  # forwards nothing to it), what comes through the privacy VPN's port mapping from anywhere
  toPorts =
    ports:
    map (port: {
      port = builtins.toString port;
      protocol = "TCP";
    }) ports.allowedTCPPorts
    ++ map (port: {
      port = builtins.toString port;
      protocol = "UDP";
    }) ports.allowedUDPPorts
    ++ map (
      { from, to }:
      {
        port = builtins.toString from;
        endPort = to;
        protocol = "TCP";
      }
    ) ports.allowedTCPPortRanges
    ++ map (
      { from, to }:
      {
        port = builtins.toString from;
        endPort = to;
        protocol = "UDP";
      }
    ) ports.allowedUDPPortRanges;
  lan = toPorts fw;
  world = lib.optionals (fw.interfaces ? privacy-vpn) (toPorts fw.interfaces.privacy-vpn);
in
{
  options.homelab.cilium.firewall = {
    enable = lib.mkEnableOption ''
      the Cilium host firewall in place of the NixOS firewall. The ports in `networking.firewall` are open to the
      `local-lan` CIDR group, those in `networking.firewall.interfaces.privacy-vpn` to any source, everything to the
      cluster
    '';
  };
  config = {
    networking.firewall = lib.mkIf enable {
      enable = false;
      allowedUDPPorts = [ 68 ]; # DHCP, seems cilium host firewall blocks this
    };
    services.k3s.manifests.cilium-hostfirewall-policy.enable = enable;
    assertions = lib.optionals enable [
      {
        assertion = config.homelab.cilium.cidr-groups.enable;
        message = "homelab.cilium.firewall opens the global ports to the local-lan CIDR group, which needs homelab.cilium.cidr-groups";
      }
      {
        assertion = lib.all (name: name == "privacy-vpn" || toPorts fw.interfaces.${name} == [ ]) (
          lib.attrNames fw.interfaces
        );
        message = "homelab.cilium.firewall maps only networking.firewall.interfaces.privacy-vpn, not ${lib.concatStringsSep ", " (lib.remove "privacy-vpn" (lib.attrNames fw.interfaces))}";
      }
    ];
    kubetree.resources.cilium-hostfirewall-policy.policy = {
      apiVersion = "cilium.io/v2";
      kind = "CiliumClusterwideNetworkPolicy";
      metadata = {
        name = "host-firewall";
      };
      spec.nodeSelector.matchLabels = { };
      spec.ingress = [
        { fromEntities = [ "cluster" ]; }
        {
          fromCIDRSet = [ { cidrGroupRef = "local-lan"; } ];
          toPortsFlattened = lan;
        }
      ]
      ++ lib.optional (world != [ ]) { toPortsFlattened = world; }
      ++ [
        {
          icmps = [
            { fields = lib.optional config.networking.firewall.allowPing { type = "EchoRequest"; }; }
          ];
        }
      ];
    };

  };
}
