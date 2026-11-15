# Alloy scrapes external-dns and its node source sidecar, through a headless Service with both metrics ports
{ inputs, ... }:
{ lib, config, ... }:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.external-dns.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes external-dns' metrics.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf config.homelab.external-dns.metrics.enable {
    homelab.alloy.monitors = {
      # external-dns' instance is a deployment, which can't hold the policies: manifests of their own
      external-dns = {
        podPort = 7979;
        manifest = null;
      };
      external-dns-node-source = {
        namespace = "external-dns";
        selector."app.kubernetes.io/name" = "external-dns";
        port = "metrics-node";
        podPort = 7980;
        manifest = null;
      };
    };
    # The deployment submodule writes no Service
    homelab.kubernetes.submodules.instances.external-dns.config.kubernetes.resources.services.external-dns =
      {
        metadata.labels."app.kubernetes.io/name" = "external-dns";
        spec = {
          clusterIP = "None";
          selector."app.kubernetes.io/name" = "external-dns";
          ports = {
            metrics.port = 7979;
            metrics-node.port = 7980;
          };
        };
      };
  };
}
