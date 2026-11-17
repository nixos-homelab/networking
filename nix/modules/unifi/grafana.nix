# UniFi's rows of the Workload dashboard, shown for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.unifi;
  j = ''namespace="unifi"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.unifi.grafana.enable = lib.mkOption {
    description = "Whether the Workload dashboard has UniFi's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.unifi.enable && config.homelab.unifi.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.drilldown.rows.unifi = {
      workload = "unifi";
      row = g.row { title = "UniFi"; } (
        g.autoGrid { columns = 3; } [
          (g.stat {
            title = "Clients";
            decimals = 0;
            queries = [
              (g.prom "unpoller_site_users{${j}}" {
                instant = true;
                legend = "{{subsystem}}";
              })
            ];
          })
          (g.table {
            title = "Devices";
            description = "Uptime, CPU and memory of each UniFi device";
            queries = [
              (g.prom "max by (name, type) (unpoller_device_uptime_seconds{${j}})" { instant = true; })
              (g.prom "max by (name, type) (unpoller_device_cpu_utilization_ratio{${j}})" { instant = true; })
              (g.prom "max by (name, type) (unpoller_device_memory_utilization_ratio{${j}})" { instant = true; })
            ];
            transformations = [
              { id = "merge"; }
              {
                id = "organize";
                options = {
                  excludeByName = {
                    Time = true;
                    site_name = true;
                    source = true;
                  };
                  renameByName = {
                    "Value #A" = "uptime (s)";
                    "Value #B" = "CPU";
                    "Value #C" = "memory";
                  };
                };
              }
            ];
          })
          (g.timeseries {
            title = "Client traffic";
            unit = "bps";
            description = "Each client; received above the line, sent below";
            queries = [
              (g.prom "sum by (name) (rate(unpoller_client_receive_bytes_total{${j}}[$__rate_interval])) * 8" {
                legend = "{{name}} in";
              })
              (g.prom "-sum by (name) (rate(unpoller_client_transmit_bytes_total{${j}}[$__rate_interval])) * 8" {
                legend = "{{name}} out";
              })
            ];
          })
          (g.bargauge {
            title = "Wi-Fi signal";
            description = "Each wireless client's signal at its access point: above -67 dBm is good for anything, orange below, red under -75 dBm where calls and streams drop";
            unit = "dBm";
            levels = g.levels {
              warn = -67;
              crit = -75;
              below = true;
            };
            queries = [
              (g.prom "unpoller_client_radio_signal_db{${j}}" {
                instant = true;
                legend = "{{name}} ({{ap_name}})";
              })
            ];
          })
          (g.timeseries {
            title = "Device traffic";
            unit = "bps";
            queries = [
              (g.prom "sum by (name) (rate(unpoller_device_bytes_total{${j}}[$__rate_interval])) * 8" {
                legend = "{{name}}";
              })
            ];
          })
        ]
      );
    };
  };
}
