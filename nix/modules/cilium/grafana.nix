# Cilium's row of the Cluster dashboard: what network policy drops and why, endpoints not ready, failing controllers
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  agent = ''job="cilium-agent"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.cilium.grafana.enable = lib.mkOption {
    description = "Whether the Cluster dashboard has Cilium's row.";
    type = lib.types.bool;
    default =
      config.homelab.cilium.enable
      && config.homelab.cilium.metrics.enable
      && config.homelab.alloy.enable
      && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.cilium.enable && config.homelab.cilium.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf config.homelab.cilium.grafana.enable {
    homelab.grafana.overviews.cluster = {
      title = "Cluster";
      rows.cilium = {
        order = 500;
        row = g.row { title = "Network policy"; } (
          g.autoGrid { columns = 3; } [
            (g.timeseries {
              title = "Dropped packets";
              unit = "pps";
              description = "By reason and direction. Policy denied is a connection no policy admits";
              queries = [
                (g.prom "sum by (reason, direction) (rate(cilium_drop_count_total{${agent}}[$__rate_interval]))" {
                  legend = "{{reason}} ({{direction}})";
                })
              ];
            })
            (g.stat {
              title = "Endpoints not ready";
              decimals = 0;
              queries = [
                (g.prom ''sum(cilium_endpoint_state{${agent}, endpoint_state!="ready"}) or vector(0)'' {
                  instant = true;
                })
              ];
              thresholds = [
                {
                  value = null;
                  color = "green";
                }
                {
                  value = 1;
                  color = "orange";
                }
              ];
            })
            (g.stat {
              title = "Failing controllers";
              decimals = 0;
              queries = [ (g.prom "sum(cilium_controllers_failing{${agent}}) or vector(0)" { instant = true; }) ];
              thresholds = [
                {
                  value = null;
                  color = "green";
                }
                {
                  value = 1;
                  color = "red";
                }
              ];
            })
          ]
        );
      };
    };
  };
}
