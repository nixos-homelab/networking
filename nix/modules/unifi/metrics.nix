# unpoller next to the controller, scraped by Alloy: it polls the controller with the read-only account that
# setup-secrets keeps in unifi-credentials and serves the result to Prometheus. It runs only while Alloy is on
{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.unifi;
  unpollerConfig = pkgs.writeTextDir "etc/unpoller/up.conf" ''
    [poller]
      quiet = true
    [prometheus]
      http_listen = "0.0.0.0:9130"
    [influxdb]
      disable = true
    [loki]
      disable = true
    [unifi.defaults]
      # The controller's certificate is for its public name
      url = "https://unifi.unifi"
      verify_ssl = false
      sites = ["all"]
  '';
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/unpoller";
    copyToRoot = [
      pkgs.unpoller
      unpollerConfig
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.User = "65534:65534";
    config.Entrypoint = [ (lib.getExe' pkgs.unpoller "unpoller") ];
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Its only port is the metrics, so the deployment's own policy admits Alloy
      { homelab.alloy.monitors.unpoller.namespace = "unifi"; }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.unpoller = {
          submodule = "deployment";
          args = {
            allowEgress = [ "unifi" ];
            ports.metrics = 9130;
            securityContext = {
              runAsUser = 65534;
              runAsGroup = 65534;
              supplementalGroups = [ ];
            };
            container = {
              image = "${image.buildArgs.name}:${image.imageTag}";
              imagePullPolicy = "Never";
              env = {
                UP_UNIFI_DEFAULT_USER.valueFrom.secretKeyRef = {
                  name = "unifi-credentials";
                  key = "username";
                };
                UP_UNIFI_DEFAULT_PASS.valueFrom.secretKeyRef = {
                  name = "unifi-credentials";
                  key = "password";
                };
              };
              # Each request to /metrics polls the controller
              livenessProbe.tcpSocket.port = "metrics";
              readinessProbe.tcpSocket.port = "metrics";
            };
          };
          config = {
            kubernetes.namespace = "unifi";
            kubernetes.resources.services.unpoller = {
              metadata.labels."app.kubernetes.io/name" = "unpoller";
              spec = {
                selector."app.kubernetes.io/name" = "unpoller";
                ports.metrics.port = 9130;
              };
            };
          };
        };
      })
    ]
  );
}
