# How the client VPN's logs are parsed: wg-quick's commands in each group's container, env_logger in the exporter
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.client-vpn;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf cfg.enable {
    homelab.alloy.logs = {
      # Rust's env_logger: [2026-11-18T07:22:07Z INFO  target] message
      formats.env_logger = {
        firstline = "^\\[\\d{4}-\\d\\d-\\d\\dT\\S+ [A-Z]+\\s";
        stages = ''
          stage.regex {
            expression = "^\\[\\S+ (?P<level>[A-Z]+)\\s+(?P<component>[^\\]]+)\\] (?s)(?P<message>.*)$"
          }
        '';
      };
      pods = {
        wireguard-exporter = {
          namespace = "client-vpn";
          format = "env_logger";
          examples = [
            {
              lines = [
                "[2026-11-18T07:22:07Z INFO  prometheus_wireguard_exporter] starting exporter on http://0.0.0.0:9586/metrics"
              ];
              expect = [
                {
                  message = "starting exporter on http://0.0.0.0:9586/metrics";
                  level = "info";
                  fields.component = "prometheus_wireguard_exporter";
                }
              ];
            }
          ];
        };
      }
      // lib.mapAttrs' (
        group: _:
        lib.nameValuePair "${group}-vpn" {
          namespace = "client-vpn";
          format = "plain";
          program = "wg-quick";
        }
      ) cfg.groups;
    };
  };
}
