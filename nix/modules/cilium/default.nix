{ inputs, self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.cilium;
  kubelib = inputs.kube-generators.lib { inherit pkgs; };
  charts = inputs.nixhelm.charts { inherit pkgs; };
  # The chart's images, preloaded from images.lock
  pins = inputs.homelab-shared.lib.pins.refs ../../../.github/workflows/pins.yaml;
  gatewayAPI =
    inputs.homelab-shared.lib.pins.locked ../../../.github/pins.lock "experimental-install"
      pins."kubernetes-sigs/gateway-api"
      (
        hash:
        pkgs.fetchurl {
          url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${
            pins."kubernetes-sigs/gateway-api"
          }/experimental-install.yaml";
          inherit hash;
        }
      );
  cilium = inputs.homelab-shared.lib.images.chart pkgs ./images.lock (
    kubelib.buildHelmChart {
      name = "cilium";
      namespace = "cilium";
      chart = charts.cilium.cilium;
      values = lib.recursiveUpdate (
        {
          hostFirewall.enabled = cfg.firewall.enable;

          ipam.mode = "kubernetes";

          routingMode = "native";
          autoDirectNodeRoutes = true;

          kubeProxyReplacement = true;

          bgpControlPlane.enabled = cfg.bgp.enable;
          nodeIPAM.enabled = true; # TODO: Needed?

          egressGateway.enabled = config.homelab.privacy-vpn.enable;

          tls.secretsNamespace.name = "cilium";
          operator.replicas = 1;
          kubeConfigPath = ccfg.kubeconfig;
          k8sServiceHost = "127.0.0.1";
          k8sServicePort = "6443";

          envoy.enabled = false;
          hubble.enabled = false;
          hubble.relay.gops.enabled = false;

          gatewayAPI.enabled = true;
          gatewayAPI.enableAlpn = true;
          gatewayAPI.enableAppProtocol = true;
          gatewayAPI.gatewayClass.create = "true";

          ipv4.enabled = ccfg.enableIPv4;
          ipv6.enabled = ccfg.enableIPv6;
          k8s.requireIPv4PodCIDR = ccfg.enableIPv4;
          k8s.requireIPv6PodCIDR = ccfg.enableIPv6;

          bpf.masquerade = cfg.masquerade.enable;
        }
        # NodePorts get past the host firewall, so serve them on the LAN's addresses only, not the privacy VPN's
        // lib.optionalAttrs (lanCIDRs != [ ]) { nodePort.addresses = lanCIDRs; }
        // lib.optionalAttrs ccfg.enableIPv4 {
          ipv4NativeRoutingCIDR = ccfg.podCidr4;
          enableIPv4Masquerade = cfg.masquerade.enable;
        }
        // lib.optionalAttrs ccfg.enableIPv6 {
          ipv6NativeRoutingCIDR = ccfg.podCidr6;
          enableIPv6Masquerade = cfg.masquerade.enable;
        }
      ) cfg.extraConfig;
    }
  );
  lanCIDRs = lib.optionals cfg.cidr-groups.enable (
    lib.remove null [
      cfg.cidr-groups.localLANCIDR4
      cfg.cidr-groups.localLANCIDR6
    ]
  );
in
{
  key = "${toString __curPos.file}#modules.nixos.cilium";
  options.homelab.cilium = {
    enable = lib.mkEnableOption "cilium";
    lbIpBlock4.cidr = lib.mkOption {
      description = "IPv4 CIDR for the load balancers";
      type = lib.types.nullOr lib.types.str;
      default = "10.44.0.0/16";
    };
    lbIpBlock4.start = lib.mkOption {
      description = "IP Pool range start for the load balancers";
      type = lib.types.str;
      default = "10.44.0.2";
    };
    lbIpBlock4.stop = lib.mkOption {
      description = "IP Pool range end for the load balancers";
      type = lib.types.str;
      default = "10.44.0.254";
    };
    lbIpBlock6.cidr = lib.mkOption {
      description = "IPv6 CIDR for the load balancers";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    lbIpBlock6.start = lib.mkOption {
      description = "IPv6 Pool range start for the load balancers";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    lbIpBlock6.stop = lib.mkOption {
      description = "IPv6 Pool range end for the load balancers";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    masquerade.enable = lib.mkOption {
      description = "Whether to turn on masquerading (automatically turned on if \${config.homelab.privacy-vpn.enable} is on)";
      type = lib.types.bool;
      default = config.homelab.privacy-vpn.enable;
      defaultText = lib.literalExpression "config.homelab.privacy-vpn.enable";
    };
    extraConfig = lib.mkOption {
      description = "Additional Cilium helm configuration values to apply";
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  imports =
    self.lib.importsApply [
      ./bgp.nix
      ./cidr-groups.nix
      ./crds.nix
      ./firewall.nix
      ./network-policies.nix
    ]
    ++ [ self.nixosModules.privacy-vpn ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.imageLocks.${toString ./images.lock} = cilium.refs;
    homelab.cluster.sourceLocks.${toString ../../../.github/pins.lock}.${gatewayAPI.key} =
      gatewayAPI.unlocked;
    assertions = [
      {
        assertion = !config.homelab.privacy-vpn.enable || cfg.masquerade.enable;
        message = "In order to use the privacy VPN, masquerading must be enabled (homelab.cilium.masquerade.enable)";
      }
    ];
    # Cilium is the Gateway API implementation and the load balancer
    homelab.cluster.providedComponents = [
      "ingress"
      "load-balancer"
    ];
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "cilium" ''KUBECONFIG=${ccfg.kubeconfig} exec ${lib.getExe pkgs.cilium-cli} "$@"'')
    ];
    # https://github.com/cilium/cilium/issues/31565#issuecomment-3419710315
    networking.firewall.checkReversePath = false;
    homelab.kubernetes = {
      submodules.defaults = [
        {
          features = [ "pod-policy" ];
          default = import ./pod-policies.nix self.lib.toPorts;
        }
      ];
      submodules.instances.cilium-lbippool = {
        submodule = "manifest";
        config.kubernetes.resources.ciliumLoadBalancerIPPools.main = {
          metadata.namespace = null;
          spec.blocks =
            lib.optional ccfg.enableIPv4 (
              if cfg.lbIpBlock4.start != null then
                { inherit (cfg.lbIpBlock4) start stop; }
              else
                { inherit (cfg.lbIpBlock4) cidr; }
            )
            ++ lib.optional ccfg.enableIPv6 (
              if cfg.lbIpBlock6.start != null then
                { inherit (cfg.lbIpBlock6) start stop; }
              else
                { inherit (cfg.lbIpBlock6) cidr; }
            );
        };
      };
    };
    homelab.cluster.images = cilium.images;
    homelab.cluster.manifests = {
      gatewayapi.source = gatewayAPI.src;
      cilium-helm.source = cilium.manifest;
    };
  };
}
