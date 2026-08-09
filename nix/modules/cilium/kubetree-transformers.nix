{ lib, transform, ... }:
with builtins;
let
  inherit (transform) mkResourceHelper;
in
{
  transformNetpolMacro =
    cfg: resource:
    let
      inherit (mkResourceHelper resource) dotPath;
      metadata =
        let
          name = dotPath "metadata.name" (throw "You must specify metadata.name");
          namespace = dotPath "metadata.namespace" name;
        in
        {
          inherit namespace;
          labels."app.kubernetes.io/name" = name;
        }
        // dotPath "metadata" (throw "You must specify metadata");
    in
    {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "cilium.io/v2";
          kind = "CiliumClusterwideNetworkPolicy";
          metadata = removeAttrs metadata [ "namespace" ] // {
            name = "pod-to-${metadata.name}";
          };
          spec.endpointSelector.matchLabels."cluster.local/${metadata.name}-egress" = "allow";
          spec.egress = [
            {
              toEndpoints = [
                {
                  matchLabels = {
                    "k8s:io.kubernetes.pod.namespace" = metadata.namespace;
                    "app.kubernetes.io/name" = metadata.name;
                  };
                }
              ];
              toPortsFlattened = dotPath "spec.ports" [ ];
            }
          ];
        }
        {
          apiVersion = "cilium.io/v2";
          kind = "CiliumNetworkPolicy";
          metadata = metadata // {
            name = "${metadata.name}-from-pod";
          };
          spec.endpointSelector.matchLabels."app.kubernetes.io/name" = metadata.name;
          spec.ingress = [
            {
              fromEndpoints = [
                {
                  matchExpressions = [
                    {
                      "key" = "k8s:io.kubernetes.pod.namespace";
                      "operator" = "Exists";
                    }
                    {
                      "key" = "cluster.local/${metadata.name}-egress";
                      "operator" = "In";
                      "values" = [ "allow" ];
                    }
                  ];
                }
              ];
              toPortsFlattened = dotPath "spec.ports" [ ];
            }
          ];
        }
      ];
    };
  transformToPortsFlattened =
    cfg: resource:
    let
      newPorts = map (
        portSpec:
        (
          if isInt portSpec then
            { port = toString portSpec; }
          else
            portSpec // { port = toString portSpec.port; }
        )
      ) (lib.attrByPath [ "toPortsFlattened" ] [ ] resource);
    in
    (removeAttrs resource [ "toPortsFlattened" ])
    // lib.optionalAttrs (length newPorts > 0) {
      toPorts = (lib.attrByPath [ "toPorts" ] [ ] resource) ++ [ { ports = newPorts; } ];
    };
}
