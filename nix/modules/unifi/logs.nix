# How the UniFi controller's and unpoller's logs are parsed. The controller writes logback's status lines and its own
# pattern, `[date] <thread> LEVEL logger - message`, with Java stack traces after them
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.unifi.enable {
    homelab.alloy.logs = {
      formats.unifi = {
        firstline = "^(?:\\d\\d:\\d\\d:\\d\\d,\\d{3} \\|-|\\[\\d{4}-\\d\\d-\\d\\dT)";
        stages = ''
          stage.regex {
            expression = "^\\d\\d:\\d\\d:\\d\\d,\\d{3} \\|-(?P<level>[A-Z]+) in (?P<component>\\S+) - (?s)(?P<message>.*)$"
          }
          stage.regex {
            expression = "^\\[[^\\]]+\\] <(?P<thread>[^>]+)> (?P<level>[A-Z]+)\\s+(?P<component>\\S+)\\s+- (?s)(?P<message>.*)$"
          }
        '';
      };
      pods = {
        unifi = {
          format = "unifi";
          examples = [
            {
              lines = [
                "07:20:13,585 |-WARN in ch.qos.logback.core.model.processor.ImplicitModelHandler - Ignoring unknown property [triggeringPolicy] in [ch.qos.logback.core.FileAppender]"
                "[2026-11-18T07:21:00,123+01:00] <db-server> ERROR db     - Got error while connecting"
                "java.net.ConnectException: Connection refused"
                "\tat java.base/sun.nio.ch.Net.connect0(Native Method)"
              ];
              expect = [
                {
                  message = "Ignoring unknown property [triggeringPolicy] in [ch.qos.logback.core.FileAppender]";
                  level = "warning";
                  fields.component = "ch.qos.logback.core.model.processor.ImplicitModelHandler";
                }
                {
                  message = lib.concatStringsSep "\n" [
                    "Got error while connecting"
                    "java.net.ConnectException: Connection refused"
                    "\tat java.base/sun.nio.ch.Net.connect0(Native Method)"
                  ];
                  level = "error";
                  fields = {
                    component = "db";
                    thread = "db-server";
                  };
                }
              ];
            }
          ];
        };
        unpoller = {
          namespace = "unifi";
          format = "golog";
          examples = [
            {
              lines = [ "2026/11/18 07:20:13 [INFO] UniFi Poller v2.39.0 Starting Up! PID: 1" ];
              expect = [
                {
                  message = "UniFi Poller v2.39.0 Starting Up! PID: 1";
                  level = "info";
                }
              ];
            }
          ];
        };
      };
    };
  };
}
