# Alloy scrapes the Cilium agent and operator, the kubelets, and the exporters that run on the hosts themselves
# (homelab.alloy.nodeTargets). All of them are on the host network: their pods, where there are any, have the host's
# identity, so no endpoint policy admits Alloy, and these egress policies let it out to `host` and `remote-node`
# instead. The host firewall already lets the cluster in on every port
{ self, inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.cilium;
  hostEgress = ports: {
    metadata.namespace = null;
    spec.egress = [
      {
        toEntities = [
          "host"
          "remote-node"
        ];
        toPorts = self.lib.toPorts ports;
      }
    ];
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf cfg.enable {
    # The agent serves none by default; a headless Service each for the ServiceMonitors
    homelab.cilium.extraConfig = {
      prometheus.enabled = true;
      prometheus.metricsService = true;
      operator.prometheus.metricsService = true;
    };
    homelab.alloy.monitors = {
      cilium-agent = {
        namespace = "cilium";
        perNode = true;
        egress = "cilium";
      };
      cilium-operator = {
        namespace = "cilium";
        egress = "cilium";
      };
    };
    homelab.kubernetes.submodules.instances.cilium-metrics = {
      submodule = "manifest";
      config.kubernetes.resources.ciliumClusterwideNetworkPolicies = {
        pod-to-cilium = lib.recursiveUpdate (hostEgress [
          {
            port = 9962;
            protocol = "TCP";
          }
          {
            port = 9963;
            protocol = "TCP";
          }
        ]) { spec.endpointSelector.matchLabels."cluster.local/cilium-egress" = "allow"; };
        pod-to-kubelet = lib.recursiveUpdate (hostEgress [
          {
            port = 10250;
            protocol = "TCP";
          }
        ]) { spec.endpointSelector.matchLabels."cluster.local/kubelet-egress" = "allow"; };
      }
      // lib.mapAttrs' (
        name: t:
        lib.nameValuePair "pod-to-${name}" (
          lib.recursiveUpdate (hostEgress [
            {
              inherit (t) port;
              protocol = "TCP";
            }
          ]) { spec.endpointSelector.matchLabels."cluster.local/${name}-egress" = "allow"; }
        )
      ) config.homelab.alloy.nodeTargets;
    };
  };
}
