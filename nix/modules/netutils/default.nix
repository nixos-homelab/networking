{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
in
{
  key = "${toString __curPos.file}#modules.nixos.netutils";
  options.homelab.netutils = {
    enable = lib.mkEnableOption "the netutils debugging container";
  };
  config = {
    homelab.kubernetes.submodules.instances.netutils = lib.mkIf config.homelab.netutils.enable {
      submodule = "manifest";
      config = {
        kubernetes.namespace = "default";
        kubernetes.resources = {
          ciliumNetworkPolicies.netutils-to-all.spec = {
            endpointSelector.matchLabels."app.kubernetes.io/name" = "netutils";
            ingress = [ { fromEntities = [ "all" ]; } ];
            egress = [ { toEntities = [ "all" ]; } ];
          };
          ciliumClusterwideNetworkPolicies.all-from-netutils = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels = { };
            spec.ingress = [
              {
                fromEndpoints = [
                  {
                    matchLabels = {
                      "k8s:io.kubernetes.pod.namespace" = "default";
                      "app.kubernetes.io/name" = "netutils";
                    };
                  }
                ];
              }
            ];
          };
          deployments.netutils = {
            metadata.labels."app.kubernetes.io/name" = "netutils";
            spec = {
              selector.matchLabels."app.kubernetes.io/name" = "netutils";
              template.metadata.labels."app.kubernetes.io/name" = "netutils";
              template.spec.containers.netutils = {
                image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
                imagePullPolicy = "Never";
                command = [
                  "iperf2"
                  "-s"
                ];
              };
            };
          };
        };
      };
    };
  };
}
