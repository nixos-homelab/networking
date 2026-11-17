# Client VPN's rows of the Workload dashboard, shown for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.client-vpn;
  j = ''namespace="client-vpn"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.client-vpn.grafana.enable = lib.mkOption {
    description = "Whether the Workload dashboard has Client VPN's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.client-vpn.enable && config.homelab.client-vpn.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.drilldown.rows.client-vpn = {
      workload = "client-vpn";
      row = g.row { title = "Client VPN"; } (
        g.autoGrid { columns = 2; } [
          (g.table {
            title = "Last handshake";
            unit = "dateTimeFromNow";
            queries = [
              (g.prom "max by (friendly_name, allowed_ips) (wireguard_latest_handshake_seconds{${j}}) * 1000" {
                instant = true;
                legend = "{{friendly_name}}";
              })
            ];
            transformations = [
              {
                id = "organize";
                options.excludeByName = {
                  Time = true;
                  public_key = true;
                };
              }
            ];
          })
          (g.timeseries {
            title = "Traffic per peer";
            unit = "bps";
            description = "Received from the peer above the line, sent to it below";
            queries = [
              (g.prom "sum by (friendly_name) (rate(wireguard_received_bytes_total{${j}}[$__rate_interval])) * 8"
                {
                  legend = "{{friendly_name}} in";
                }
              )
              (g.prom "-sum by (friendly_name) (rate(wireguard_sent_bytes_total{${j}}[$__rate_interval])) * 8" {
                legend = "{{friendly_name}} out";
              })
            ];
          })
        ]
      );
    };
  };
}
