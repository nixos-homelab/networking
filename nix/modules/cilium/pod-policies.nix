# The Cilium policies of the policy intent of a pod (shared `policy.nix`), added to every submodule with it through
# `submodules.defaults`: pods labeled `cluster.local/<name>-egress: allow` may reach the `policyPorts` from any
# namespace, the API server the `apiServerPorts`, the world the `worldPorts`
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
  labels = config.policySelector;
  egressLabel = "cluster.local/${name}-egress";
  portsOf = map (
    n:
    let
      p = args.ports.${n};
    in
    { port = p.containerPort; } // lib.optionalAttrs (p.protocol != null) { inherit (p) protocol; }
  );
  ports = portsOf args.policyPorts;
  # Ingress to the pods from an entity
  fromEntity = entity: portNames: {
    metadata = { inherit labels; };
    spec = {
      endpointSelector.matchLabels = labels;
      ingress = [
        {
          fromEntities = [ entity ];
          toPorts = toPorts (portsOf portNames);
        }
      ];
    };
  };
in
{
  kubernetes.resources = lib.mkMerge [
    (lib.mkIf (ports != [ ]) {
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
    })
    (lib.mkIf (args.apiServerPorts != [ ]) {
      ciliumNetworkPolicies."${name}-from-apiserver" = fromEntity "kube-apiserver" args.apiServerPorts;
    })
    (lib.mkIf (args.worldPorts != [ ]) {
      ciliumNetworkPolicies."${name}-from-world" = fromEntity "world" args.worldPorts;
    })
  ];
}
