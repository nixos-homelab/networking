# unpoller beside the controller, scraped by Alloy: it polls the controller's Service with the read-only account that
# setup-secrets keeps in unifi-credentials and serves the result to Prometheus. A Deployment of its own, so the
# controller doesn't wait for that account, which is made in the controller's UI. It runs only while Alloy is on
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
    # The image config references the store path, which puts it in the image (a store path named only by the Pod's
    # command isn't)
    config.Entrypoint = [ (lib.getExe' pkgs.unpoller "unpoller") ];
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.unifi.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes the UniFi controller's metrics, and runs unpoller for them.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) (
    lib.mkMerge [
      {
        homelab.alloy.monitors.unifi = {
          selector."app.kubernetes.io/name" = "unpoller";
          podPort = 9130;
        };
      }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.unifi.config.submodules.instances = {
          unpoller = {
            submodule = "deployment";
            args = {
              allowEgress = [ "unifi" ];
              ports.metrics = 9130;
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
                securityContext = {
                  runAsUser = 65534;
                  runAsGroup = 65534;
                  runAsNonRoot = true;
                  allowPrivilegeEscalation = false;
                  readOnlyRootFilesystem = true;
                  capabilities.drop = [ "ALL" ];
                };
                # Each request to /metrics polls the controller
                livenessProbe.tcpSocket.port = "metrics";
                readinessProbe.tcpSocket.port = "metrics";
              };
            };
          };
          # A key apart from the Deployment instance, the same object name
          unpoller-service = {
            name = "unpoller";
            submodule = "service";
            args.ports.metrics = 9130;
          };
        };
      })
    ]
  );
}
