# A WireGuard exporter next to each group's WireGuard, scraped by Alloy: the peers' handshakes and traffic, named
# after the peers. It runs only while Alloy is on
{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.client-vpn;
  port = 9586;
  # Runs `wg show all dump`, which needs wg in PATH
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/wireguard-exporter";
    copyToRoot = [
      pkgs.prometheus-wireguard-exporter
      pkgs.wireguard-tools
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.User = "0:0";
    config.Env = [ "PATH=/bin" ];
    config.Entrypoint = [ (lib.getExe pkgs.prometheus-wireguard-exporter) ];
  };
  # The exporter takes peer names from friendly_name comments in [Peer] sections of a WireGuard config. Its parser
  # rejects a [Peer] without AllowedIPs (prometheus_wireguard_exporter 3.6.6 src/wireguard_config.rs), and every
  # /metrics then fails, the readiness probe with it; so each peer has the AllowedIPs of the real config. No keys
  peerNames =
    spec:
    lib.concatStrings (
      lib.mapAttrsToList (name: peer: ''
        [Peer]
        # friendly_name = ${name}
        PublicKey = ${peer.publicKey}
        AllowedIPs = ${
          lib.concatStringsSep "," (
            lib.filter (ip: ip != null) [
              peer.ipv4
              peer.ipv6
            ]
          )
        }

      '') (lib.filterAttrs (_: peer: peer.enable) spec.peers)
    );
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # The pods' own port is WireGuard's
        homelab.alloy.monitors.client-vpn.podPort = port;
      }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.client-vpn.config = {
          kubernetes.resources.configMaps.client-vpn-peer-names = {
            metadata.labels."app.kubernetes.io/name" = "client-vpn";
            data = lib.mapAttrs' (group: spec: lib.nameValuePair "${group}.conf" (peerNames spec)) cfg.groups;
          };
          submodules.instances = {
            # A key apart from the manifest instance, the same object name; it selects the pods of every group
            client-vpn-service = {
              name = "client-vpn";
              submodule = "service";
              args.ports.metrics = port;
            };
          }
          // lib.mapAttrs' (
            group: _spec:
            lib.nameValuePair "${group}-vpn" {
              config.kubernetes.resources.deployments."${group}-vpn".spec.template.spec = {
                containers.wireguard-exporter = {
                  image = "${image.buildArgs.name}:${image.imageTag}";
                  imagePullPolicy = "Never";
                  args = [
                    "--extract_names_config_files"
                    "/peer-names/${group}.conf"
                  ];
                  ports.metrics.containerPort = port;
                  securityContext = {
                    # wg reads the device over netlink
                    runAsUser = 0;
                    runAsGroup = 0;
                    allowPrivilegeEscalation = false;
                    readOnlyRootFilesystem = true;
                    capabilities.add = [ "NET_ADMIN" ];
                    capabilities.drop = [ "ALL" ];
                  };
                  livenessProbe.tcpSocket.port = "metrics";
                  readinessProbe.httpGet = {
                    path = "/metrics";
                    port = "metrics";
                  };
                  volumeMounts."/peer-names".name = "peer-names";
                };
                volumes.peer-names.configMap.name = "client-vpn-peer-names";
              };
            }
          ) cfg.groups;
        };
      })
    ]
  );
}
