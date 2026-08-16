# Cilium network policies

Custom `kubetree.resources` machinery for Cilium network policies, wired
up by `kubetree.cilium.enable`.

## NetpolMacro

Expands into the pair of Cilium policies enforcing the
`allowIngress`/`allowEgress` labels [workload
macros](https://github.com/nixos-homelab/shared/blob/main/docs/workload-macros.md)
put on pods: a `CiliumClusterwideNetworkPolicy` letting anything labeled
`cluster.local/<name>-egress: allow` reach the workload named `<name>` on
`spec.ports`, and a `CiliumNetworkPolicy` on the workload allowing ingress
from anything carrying that same label, across namespaces.

`WorkloadMacro` creates one of these automatically for any workload with
container ports. Can also be used directly:

```nix
kubetree.resources.node-exporter.netpol = {
  apiVersion = "cluster.local";
  kind = "NetpolMacro";
  metadata.name = "node-exporter";
  spec.ports = [ 9100 ];
};
```

## `toPortsFlattened`

A shorthand for `spec.ingress[]`/`spec.egress[]` on any real
`CiliumNetworkPolicy` or `CiliumClusterwideNetworkPolicy` (not just ones
`NetpolMacro` produces): a plain list of ports -- bare numbers or
`{ port; protocol; }` attrsets -- instead of Cilium's native nested
`toPorts = [ { ports = [...]; } ];` shape. Port numbers are stringified.

```nix
spec.egress = [
  {
    toEntities = [ "world" ];
    toPortsFlattened = [
      { port = 53; protocol = "UDP"; }
      443
    ];
  }
];
```

turns into

```nix
spec.egress = [
  {
    toEntities = [ "world" ];
    toPorts = [
      {
        ports = [
          { port = "53"; protocol = "UDP"; }
          { port = "443"; }
        ];
      }
    ];
  }
];
```
