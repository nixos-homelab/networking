# Cilium network policies

The policies of kubenix pods and `lib.toPorts`, and the
`kubetree.resources` machinery that does the same for the workload
macros, wired up by `kubetree.cilium.enable`.

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

## kubenix pods

The same pair of policies for every instance of a
[submodule that runs pods](https://github.com/nixos-homelab/shared/blob/main/nix/modules/workloads/README.md)
(`workload`, `deployment`, `daemonset`, `job`, `cronjob`), on its
`policyPorts`, all of its `ports` unless set; added through kubenix
`submodules.defaults` when `homelab.cilium.enable` is set. They go in the
manifest of the instance; change them through its `config`, as
`kubernetes.resources.ciliumClusterwideNetworkPolicies.pod-to-<name>`
and `kubernetes.resources.ciliumNetworkPolicies.<name>-from-pod`.

## `lib.toPorts`

Cilium's `toPorts` from a flat list of ports as a NetworkPolicy writes
them, for policies written by hand: port numbers, or `{ port; protocol; }`
(and `endPort`). Cilium wants the port as a string. No ports give
null, which leaves the field out.

```nix
homelab.kubernetes.kubernetes.resources.ciliumNetworkPolicies.dns.spec.egress = [
  {
    toEntities = [ "world" ];
    toPorts = inputs.homelab-networking.lib.toPorts [
      { port = 53; protocol = "UDP"; }
      443
    ];
  }
];
```

gives `toPorts = [ { ports = [ { port = "53"; protocol = "UDP"; } { port = "443"; } ]; } ]`.

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
