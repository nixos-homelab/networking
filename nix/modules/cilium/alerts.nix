# Cilium's alert rules, both info for now (Home's Firing list, no notification): network policy denying traffic,
# and the datapath dropping packets for other reasons. The drops threshold is a guess until a baseline of the live
# cluster is measured; Unsupported L2/L3 protocol and Unknown L3 target address are broadcast and IPv6 noise and left
# out
{ inputs, ... }:
{ lib, config, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.cilium;
  agent = ''job="cilium-agent"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.cilium.alerts.enable = lib.mkOption {
    description = "Whether Grafana alerts on Cilium's policy denials and drops.";
    type = lib.types.bool;
    default =
      cfg.enable
      && cfg.metrics.enable
      && config.homelab.alloy.enable
      && config.homelab.grafana.alerting.enable;
    defaultText = lib.literalExpression ''
      config.homelab.cilium.enable && config.homelab.cilium.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.alerting.enable
    '';
  };
  config = lib.mkIf cfg.alerts.enable {
    homelab.grafana.alerting.groups.cilium.rules = {
      policy-denied = g.alert {
        title = "Network policy denying traffic";
        query = ''sum by (direction) (rate(cilium_drop_count_total{${agent}, reason="Policy denied"}[5m]))'';
        above = 0;
        for = "15m";
        severity = "info";
        summary = "Network policy drops {{ $values.B.Value }} packets/s ({{ $labels.direction }}): a pod is talking to something it isn't allowed to";
        dashboardUid = "cluster";
      };
      drops = g.alert {
        title = "Cilium dropping packets";
        query = ''sum by (reason, direction) (rate(cilium_drop_count_total{${agent}, reason!~"Policy denied|Unsupported L2 protocol|Unsupported L3 protocol|Unknown L3 target address"}[5m]))'';
        above = 1;
        for = "15m";
        severity = "info";
        summary = "Cilium drops {{ $values.B.Value }} packets/s for {{ $labels.reason }} ({{ $labels.direction }})";
        dashboardUid = "cluster";
      };
    };
  };
}
