# Cilium's panels of the Cluster dashboard: the traffic it forwards and drops, why it drops, how full its BPF maps are,
# and its endpoints and controllers as tiles
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  agent = ''job="cilium-agent"'';
  pressure = g.levels {
    warn = 0.8;
    crit = 0.9;
  };
  panel = order: w: h: panel: {
    inherit
      order
      w
      h
      panel
      ;
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.cilium.grafana.enable = lib.mkOption {
    description = "Whether the Cluster dashboard has Cilium's panels.";
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
      panels = {
        endpoints = panel 24 3 4 (
          g.ratio {
            title = "Endpoints";
            description = "Cilium's endpoints (a pod each, and the host) whose policy is in place, of all of them";
            good = ''sum(cilium_endpoint_state{${agent}, endpoint_state="ready"})'';
            all = "sum(cilium_endpoint{${agent}})";
          }
        );
        denied = panel 25 3 4 (
          g.stat {
            title = "Policy denied";
            description = "Packets a network policy dropped, per second: a pod talking to something it isn't allowed to. The drops graph has where they go";
            unit = "pps";
            queries = [
              (g.prom
                ''sum(rate(cilium_drop_count_total{${agent}, reason="Policy denied"}[$__rate_interval])) or vector(0)''
                { }
              )
            ];
          }
        );
        map-pressure = panel 26 3 4 (
          g.stat {
            title = "BPF maps";
            description = "How full Cilium's fullest BPF map is: a full connection-tracking or NAT map drops new connections. Orange from 80 %, red from 90 %";
            unit = "percentunit";
            levels = pressure;
            queries = [ (g.prom "max(cilium_bpf_map_pressure{${agent}})" { }) ];
          }
        );
        controller-failures = panel 27 3 4 (
          g.stat {
            title = "Controllers";
            description = "Runs of Cilium's controllers (the loops keeping endpoints, identities and policy in sync) that failed in the hour before; orange from 1, red from 10";
            decimals = 0;
            levels = g.levels {
              warn = 1;
              crit = 10;
            };
            queries = [
              (g.prom
                ''sum(increase(cilium_controllers_runs_total{${agent}, status="failure"}[1h])) or vector(0)''
                { }
              )
            ];
          }
        );
        traffic = panel 500 8 8 (
          g.timeseries {
            title = "Forwarded and dropped";
            description = "The traffic Cilium's datapath forwarded, above the line, and dropped, below, in both directions together";
            unit = "Bps";
            queries = [
              (g.prom "sum(rate(cilium_forward_bytes_total{${agent}}[$__rate_interval]))" {
                legend = "forwarded";
              })
              (g.prom "-sum(rate(cilium_drop_bytes_total{${agent}}[$__rate_interval]))" { legend = "dropped"; })
            ];
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "dropped";
                };
                properties = [
                  {
                    id = "color";
                    value = {
                      mode = "fixed";
                      fixedColor = "orange";
                    };
                  }
                ];
              }
            ];
          }
        );
        drops = panel 501 8 8 (
          g.timeseries {
            title = "Drops by reason";
            description = "Packets dropped per second, by reason and direction, stacked. Policy denied is network policy at work; Unsupported L2/L3 protocol and Unknown L3 target address are mostly broadcast and IPv6 noise the datapath has no use for";
            unit = "pps";
            legend = "right";
            custom = {
              stacking.mode = "normal";
              fillOpacity = 50;
            };
            queries = [
              (g.prom "sum by (reason, direction) (rate(cilium_drop_count_total{${agent}}[$__rate_interval])) > 0"
                {
                  legend = "{{reason}} ({{direction}})";
                }
              )
            ];
            options.legend.width = 360;
          }
        );
        maps = panel 502 8 8 (
          g.bargauge {
            title = "BPF map pressure";
            description = "The ten fullest of Cilium's BPF maps; ct is connection tracking, nat the NAT table, ipcache the identities of the cluster's addresses. Orange from 80 %, red from 90 %";
            unit = "percentunit";
            min = 0;
            max = 1;
            levels = pressure;
            queries = [
              (g.prom "topk(10, max by (map_name) (cilium_bpf_map_pressure{${agent}}))" {
                instant = true;
                legend = "{{map_name}}";
              })
            ];
          }
        );
      };
    };
  };
}
