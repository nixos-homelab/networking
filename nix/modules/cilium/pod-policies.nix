# The Cilium policies of a pod with `policyPorts`, added to every submodule that runs pods through
# `submodules.defaults`: pods labeled `cluster.local/<name>-egress: allow` may reach those ports, from any namespace
toPorts:
{
  lib,
  name,
  args,
  config,
  ...
}:
let
  inherit (config.kubernetes) namespace;
  labels."app.kubernetes.io/name" = name;
  egressLabel = "cluster.local/${name}-egress";
  ports = map (
    n:
    let
      p = args.ports.${n};
    in
    { port = p.containerPort; } // lib.optionalAttrs (p.protocol != null) { inherit (p) protocol; }
  ) args.policyPorts;
in
{
  kubernetes.resources = lib.mkIf (ports != [ ]) {
    ciliumClusterwideNetworkPolicies."pod-to-${name}" = {
      metadata = {
        inherit labels;
        namespace = null;
      };
      spec = {
        endpointSelector.matchLabels.${egressLabel} = "allow";
        egress = [
          {
            toEndpoints = [ { matchLabels = labels // { "k8s:io.kubernetes.pod.namespace" = namespace; }; } ];
            toPorts = toPorts ports;
          }
        ];
      };
    };
    ciliumNetworkPolicies."${name}-from-pod" = {
      metadata = { inherit labels; };
      spec = {
        endpointSelector.matchLabels = labels;
        ingress = [
          {
            fromEndpoints = [
              {
                matchExpressions = [
                  {
                    key = "k8s:io.kubernetes.pod.namespace";
                    operator = "Exists";
                  }
                  {
                    key = egressLabel;
                    operator = "In";
                    values = [ "allow" ];
                  }
                ];
              }
            ];
            toPorts = toPorts ports;
          }
        ];
      };
    };
  };
}
