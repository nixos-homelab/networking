# unpoller as a sidecar of the controller, scraped by Alloy: it polls the controller over localhost with the read-only
# account that setup-secrets keeps in unifi-credentials and serves the result to Prometheus. It runs only while Alloy
# is on, and turning Alloy on or off restarts the controller
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
      url = "https://127.0.0.1:8443"
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
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        homelab.alloy.monitors.unifi = {
          # The controller's other ports are its own
          podPort = 9130;
          # Its instance is a workload, which can't hold the policy (kubenix nesting): a manifest of its own
          manifest = null;
        };
      }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.unifi.config.kubernetes.resources = {
          deployments.unifi.spec.template = {
            # The sidecar sorts first, where kubectl logs and exec would go without -c
            metadata.annotations."kubectl.kubernetes.io/default-container" = "unifi";
            spec.containers.unpoller = {
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
              ports.metrics.containerPort = 9130;
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
          services.unifi.spec.ports.metrics.port = 9130;
        };
      })
    ]
  );
}
