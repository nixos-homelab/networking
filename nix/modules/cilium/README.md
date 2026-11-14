# Cilium network policies

The policies of kubenix pods, the Cilium types and `lib.toPorts`.

## kubenix pods

The policies of the CNI-neutral intent of every instance of a
[submodule that runs pods, or of `pods`](https://github.com/nixos-homelab/shared/blob/main/nix/modules/workloads/README.md)
(the feature `pod-policy`), added through kubenix `submodules.defaults`
when `homelab.cilium.enable` is set. They select the pods by
`app.kubernetes.io/name` of the instance, or the `selector` of `pods`:

- `policyPorts`, all of `ports` unless set: pods labeled
  `cluster.local/<name>-egress: allow` in any namespace may reach them,
  through the CiliumClusterwideNetworkPolicy `pod-to-<name>` and the
  CiliumNetworkPolicy `<name>-from-pod`.
- `apiServerPorts`: the API server may reach them, `<name>-from-apiserver`.
- `worldPorts`: the world outside the cluster may reach them,
  `<name>-from-world`.

They go in the manifest of the instance; change them through its
`config`, as `kubernetes.resources.ciliumNetworkPolicies.<name>-from-pod`.

## Cilium types

`nixosModules.cilium-crds` (which `cilium` imports) adds the kubenix
types of the Cilium CRDs, of the version of the chart `cilium` installs,
and of ClusterNetworkPolicy, and hands the CRDs to the manifests check
through `homelab.cluster.runtimeCRDs`, as Cilium's operator creates them
at runtime. It deploys nothing: a module that writes Cilium policies by
hand imports it, so it evaluates with Cilium off too.

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
