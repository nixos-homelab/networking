# The kubenix types of the Cilium CRDs, of the version the cilium module installs, for every module that writes such
# resources. Cilium's operator creates its CRDs at runtime, so the manifests check gets
# them through `homelab.cluster.runtimeCRDs`. Types only: it deploys nothing, so it is imported whether or not
# `homelab.cilium.enable` is set.
{ inputs, ... }:
{
  lib,
  pkgs,
  ...
}:
let
  shared = inputs.homelab-shared.lib;
  kubelib = inputs.kube-generators.lib { inherit pkgs; };
  pinned = shared.pins.locked ../../../.github/pins.lock;
  # The version of the chart the cilium module installs
  version = "v${inputs.nixhelm.chartsMetadata.cilium.cilium.version}";
  ciliumDir = "pkg/k8s/apis/cilium.io/client/crds/v2";
  cilium = pinned "cilium-crds" version (
    hash:
    pkgs.fetchFromGitHub {
      owner = "cilium";
      repo = "cilium";
      rev = version;
      sparseCheckout = [ ciliumDir ];
      inherit hash;
    }
  );
  files = lib.filter (lib.hasSuffix ".yaml") (lib.filesystem.listFilesRecursive "${cilium.src}/${ciliumDir}");
in
{
  key = "${toString __curPos.file}#modules.nixos.cilium-crds";
  homelab.cluster.sourceLocks.${toString ../../../.github/pins.lock}.${cilium.key} = cilium.unlocked;
  homelab.cluster.runtimeCRDs = files;
  homelab.kubernetes.kubernetes.customTypes = lib.concatMap shared.crd2types.customTypes (
    lib.filter (d: d.kind or null == "CustomResourceDefinition") (
      kubelib.fromYAML (lib.concatMapStringsSep "\n---\n" builtins.readFile files)
    )
  );
}
