{ self, ... }:
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
  portsOf =
    ports:
    map (port: {
      inherit port;
      protocol = "TCP";
    }) ports.allowedTCPPorts
    ++ map (port: {
      inherit port;
      protocol = "UDP";
    }) ports.allowedUDPPorts
    ++ map (
      { from, to }:
      {
        port = from;
        endPort = to;
        protocol = "TCP";
      }
    ) ports.allowedTCPPortRanges
    ++ map (
      { from, to }:
      {
        port = from;
        endPort = to;
        protocol = "UDP";
      }
    ) ports.allowedUDPPortRanges;
  lan = portsOf fw;
  world = lib.optionals (fw.interfaces ? privacy-vpn) (portsOf fw.interfaces.privacy-vpn);
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
    assertions = lib.optionals enable [
      {
        assertion = config.homelab.cilium.cidr-groups.enable;
        message = "homelab.cilium.firewall opens the global ports to the local-lan CIDR group, which needs homelab.cilium.cidr-groups";
      }
      {
        assertion = lib.all (name: name == "privacy-vpn" || portsOf fw.interfaces.${name} == [ ]) (
          lib.attrNames fw.interfaces
        );
        message = "homelab.cilium.firewall maps only networking.firewall.interfaces.privacy-vpn, not ${lib.concatStringsSep ", " (lib.remove "privacy-vpn" (lib.attrNames fw.interfaces))}";
      }
    ];
    homelab.kubernetes.submodules.instances.cilium-hostfirewall-policy = lib.mkIf enable {
      submodule = "manifest";
      config.kubernetes.resources.ciliumClusterwideNetworkPolicies.host-firewall = {
        metadata.namespace = null;
        spec.nodeSelector.matchLabels = { };
        spec.ingress = [
          { fromEntities = [ "cluster" ]; }
        ]
        # Without ports the rule would open every port to the LAN
        ++ lib.optional (lan != [ ]) {
          fromCIDRSet = [ { cidrGroupRef = "local-lan"; } ];
          toPorts = self.lib.toPorts lan;
        }
        ++ lib.optional (world != [ ]) { toPorts = self.lib.toPorts world; }
        ++ [
          {
            icmps = [
              { fields = lib.optional config.networking.firewall.allowPing { type = "EchoRequest"; }; }
            ];
          }
        ];
      };
    };
  };
}
