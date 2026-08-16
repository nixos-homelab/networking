# nixos-homelab-networking

The networking base that ties the rest of the homelab together. Every
workload across every `nixos-homelab-*` repo declares `allowIngress`/
`allowEgress` on its [workload
macros](https://github.com/nixos-homelab/shared/blob/main/docs/workload-macros.md)
-- this repo's `cilium` module is what actually enforces them as network
policy; without it they're just labels. It also provides the CNI itself,
inbound and outbound VPNs, routable IP pools, and DNS management.

See the [Cilium network policies docs](docs/cilium.md) for the custom
resource kinds this repo's `kubetree.cilium` module adds, and
[docs/options.md](docs/options.md) for the full list of module options.

## Setup

```nix
{
  inputs = {
    ...
    homelab-networking = {
      url = "github:nixos-homelab/networking";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ...
  };
}
```

```nix
{ inputs, ... }:
{
  imports = [ inputs.homelab-networking.nixosModules.cilium ];
  config.homelab.cilium.enable = true;
}
```

## Modules

- **cilium**: the [Cilium](https://cilium.io) CNI, plus the LoadBalancer
  IP pool it hands out from -- see [docs/cilium.md](docs/cilium.md) for
  the `NetpolMacro`/`toPortsFlattened` resource kinds it also adds.
- **routed-ippool**: a routable IPv4 pool for LoadBalancer services,
  routed to the cluster from the LAN.
- **client-vpn**: the inbound WireGuard gateway -- named access groups,
  each scoped to specific services or full cluster access, for remote
  `kubectl`/service access.
- **privacy-vpn**: an outbound WireGuard tunnel to an external VPN
  provider, for routing a workload's egress traffic through it (e.g.
  `homelab-media`'s `rtorrent`).
- **external-dns**: [external-dns](https://github.com/kubernetes-sigs/external-dns),
  managing DNS records for cluster services automatically.
- **unifi**: Unifi Network Controller, for managing Ubiquiti networking
  gear.
- **netutils**: a debugging container with common networking tools, for
  troubleshooting from inside the cluster.
