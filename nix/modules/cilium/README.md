# Cilium network policies

The policies of kubenix pods and `lib.toPorts`.

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
