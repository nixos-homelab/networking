# networking

- The classic Java UniFi controller (`nix/modules/unifi`, `homelab.unifi`) runs on the NAS. Its mongodb is
  pinned and unfree, so it's never substituted and a source build takes hours.
- UniFi OS Server on Kubernetes was abandoned on 2026-07-31 because it doesn't work. Don't propose resuming it.
