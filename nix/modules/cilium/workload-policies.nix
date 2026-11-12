# The Cilium policies of a workload with ports, added to every `workload` instance through `submodules.defaults`:
# pods labeled `cluster.local/<workload>-egress: allow` may reach the workload on its ports, from any namespace
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
  toPorts = [
    {
      ports = lib.mapAttrsToList (
        _: p: { port = toString p.containerPort; } // lib.optionalAttrs (p.protocol != null) { inherit (p) protocol; }
      ) args.ports;
    }
  ];
in
{
  kubernetes.resources = lib.mkIf (args.ports != { }) {
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
            inherit toPorts;
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
            inherit toPorts;
          }
        ];
      };
    };
  };
}
