{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.client-vpn;
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
  hllib = inputs.homelab-shared.lib;
  systemd-creds = lib.getExe' pkgs.systemd "systemd-creds";
  credential = name: "wireguard-homelab-${name}-private-key";
  credstoreKey = name: "/etc/credstore.encrypted/${credential name}";
  listenPort = 51820;
  upScript = pkgs.writeShellScriptBin "up.sh" ''
    ${lib.getExe' pkgs.wireguard-tools "wg-quick"} up clients
    for sig in INT TERM EXIT; do
      trap "${lib.getExe' pkgs.wireguard-tools "wg-quick"} down clients; kill $SLEEP_PID" $sig
    done
    (while true; do sleep 600; done) &
    wait $!
  '';
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/wireguard";
    copyToRoot = [
      pkgs.bash
      upScript
      pkgs.iptables
      pkgs.wireguard-tools
      pkgs.coreutils # needed by wg-quick
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.User = "0:0";
    config.Entrypoint = [
      (pkgs.lib.getExe upScript)
    ];
  };
  labels = group: {
    "app.kubernetes.io/name" = "client-vpn";
    "app.kubernetes.io/component" = group;
  };
  # The pods of every group are named client-vpn, over the instance name the deployment submodule gives them; a
  # Deployment selector is immutable
  forcedLabels = group: labels group // { "app.kubernetes.io/name" = lib.mkForce "client-vpn"; };
  enabledPeerConfigs = peers: lib.filterAttrs (_name: value: value.config.enable) peers;
  enabledGroupConfigs =
    lib.mapAttrs (_name: value: builtins.head (builtins.attrValues (enabledPeerConfigs value.peers)))
      (
        lib.filterAttrs (
          _name: value: builtins.length (builtins.attrNames (enabledPeerConfigs value.peers)) == 1
        ) cfg.groups
      );
in
{
  key = "${toString __curPos.file}#modules.nixos.client-vpn";
  options.homelab.client-vpn = {
    enable = lib.mkEnableOption "the client VPN gateway";
    debug = lib.mkEnableOption "debug mode";
    groups = lib.mkOption {
      description = "VPN client access groups, indexed by group name. Each group is a wireguard endpoint.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { ... }:
          {
            options = {
              allowEgress = lib.mkOption {
                description = "List of services this group should be granted access to \"gateway\" is needed for access to gateway (use e.g. [\"gateway\" \"sabnzbd\"] to grant access to sabnzbd only), \"cluster\" gives full access to the cluster";
                type = lib.types.listOf lib.types.str;
              };
              reservedIPs = lib.mkOption {
                description = "Reserved IPs for the VPN endpoint";
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              cidr4 = lib.mkOption {
                description = "IPv4 CIDR of the tunnel";
                type = lib.types.str;
              };
              cidr6 = lib.mkOption {
                description = "IPv6 CIDR of the tunnel";
                type = lib.types.str;
              };
              gatewayIPv4 = lib.mkOption {
                description = "IPv4 of the gateway";
                type = lib.types.str;
                readOnly = true;
              };
              gatewayIPv6 = lib.mkOption {
                description = "IPv6 of the gateway";
                type = lib.types.str;
                readOnly = true;
              };
              gatewayPublicKey = lib.mkOption {
                description = "Public key of the gateway for inline in ready-made client configurations";
                type = lib.types.str;
              };
              peers = lib.mkOption {
                description = "VPN Peers in this group";
                type = lib.types.attrsOf (
                  lib.types.submodule (
                    {
                      name,
                      config,
                      ...
                    }:
                    {
                      options = {
                        enable = lib.mkEnableOption "the peer";
                        config.enable = lib.mkEnableOption "the wireguard & setup-secrets configuration corresponding to this peer, at most one configuration per group can be enabled at the same time";
                        publicKey = lib.mkOption {
                          description = "Public key of the peer";
                          type = lib.types.str;
                        };
                        ipv4 = lib.mkOption {
                          description = "The IPv4 of the peer";
                          type = lib.types.nullOr lib.types.str;
                        };
                        ipv6 = lib.mkOption {
                          description = "The IPv6 of the peer";
                          type = lib.types.nullOr lib.types.str;
                        };
                      };
                    }
                  )
                );
              };
            };
          }
        )
      );
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    self.nixosModules.routed-ippool
  ];
  config = {
    assertions =
      (lib.optional cfg.enable {
        assertion = config.homelab.routed-ippool.enable;
        message = "Client VPN depends on the routed loadbalancer IP Pool module. Enable with `homelab.routed-ippool = { enable=true; lbIpBlock4.cidr = ...; }`";
      })
      ++ (lib.mapAttrsToList (
        name: value:
        let
          names = builtins.attrNames (enabledPeerConfigs value.peers);
        in
        {
          assertion = builtins.length names <= 1;
          message = "The Client VPN group '${name}' has multiple peer configurations enabled (${lib.join ", " names}), this is not supported";
        }
      ) cfg.groups);
    networking.wireguard.interfaces = lib.mapAttrs' (name: value: {
      name = "homelab-${name}";
      value = {
        ips = lib.mkDefault (
          lib.filter (ip: ip != null) [
            value.ipv4
            value.ipv6
          ]
        );
        mtu = lib.mkDefault 1280;
        peers = [
          {
            allowedIPs = lib.mkDefault (
              (lib.optional ccfg.enableIPv4 config.homelab.cilium.lbIpBlock4.cidr)
              ++ (lib.optional ccfg.enableIPv6 config.homelab.cilium.lbIpBlock6.cidr)
            );
            endpoint = lib.mkDefault "${name}-vpn.${config.homelab.workloads.domain}:51820";
            publicKey = lib.mkDefault cfg.groups.${name}.gatewayPublicKey;
          }
        ];
        # A credential name, not a path: systemd looks it up in the credstore
        privateKeyFile = lib.mkDefault (credential name);
      };
    }) enabledGroupConfigs;
    # nixpkgs loads privateKeyFile with LoadCredential, which doesn't decrypt. The unit lists this after it, so it
    # replaces those entries. A missing key only drops its interface.
    systemd.services.systemd-networkd.serviceConfig.LoadCredentialEncrypted = map credential (
      builtins.attrNames enabledGroupConfigs
    );
    setup-secrets.sources =
      (lib.mapAttrs' (group: _spec: {
        name = "CLIENT_VPN_${lib.toUpper group}";
        value = {
          enable = cfg.enable;
          description = "Client VPN ${group} private key";
          cmd = hllib.setup-secrets.mkScript pkgs ''
            getKubeSecret client-vpn client-vpn-private-keys ${group} || \
            ${lib.getExe' pkgs.wireguard-tools "wg"} genkey
          '';
        };
      }) cfg.groups)
      // (lib.mapAttrs' (name: _value: {
        name = "HOMELAB_${lib.toUpper name}_VPN_PRIVATE_KEY";
        value = {
          description = "Private Key for homelab ${name} VPN connection";
          cmd = hllib.setup-secrets.mkScript pkgs "${systemd-creds} decrypt ${credstoreKey name} -";
        };
      }) enabledGroupConfigs);
    setup-secrets.destinations = [
      {
        enable = cfg.enable;
        logPrefix = "Client VPN Private Keys";
        requires = map (group: "CLIENT_VPN_${lib.toUpper group}") (builtins.attrNames cfg.groups);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret client-vpn client-vpn-private-keys \
            ${lib.join "\\ \n" (
              map (group: ''${group} "$CLIENT_VPN_${lib.toUpper group}"'') (builtins.attrNames cfg.groups)
            )}
        '';
      }
    ]
    ++ (lib.mapAttrsToList (
      name: _value:
      let
        envvar = "HOMELAB_${lib.toUpper name}_VPN_PRIVATE_KEY";
      in
      {
        logPrefix = "Homelab ${name} VPN Private Key";
        requires = [ envvar ];
        cmd = hllib.setup-secrets.mkScript pkgs ''
          if [[ ! -e ${credstoreKey name} ]] ||
            [[ $(${systemd-creds} decrypt ${credstoreKey name} -) != "$${envvar}" ]]; then
            mkdir -p -m 700 /etc/credstore.encrypted
            printf "%s" "$${envvar}" |
              ${systemd-creds} encrypt --with-key=tpm2 --name=${credential name} - ${credstoreKey name}
            # networkd only imports credentials when it starts
            ${lib.getExe' pkgs.systemd "systemctl"} try-restart systemd-networkd.service
          fi
        '';
      }
    ) enabledGroupConfigs);
    homelab.cluster.images = lib.optional cfg.enable image;
    homelab.kubernetes.submodules.instances.client-vpn = lib.mkIf cfg.enable {
      submodule = "manifest";
      config = {
        kubernetes.resources = {
          namespaces.client-vpn.metadata.namespace = null;
          configMaps.client-vpn = {
            metadata.labels."app.kubernetes.io/name" = "client-vpn";
            data = lib.mapAttrs' (group: spec: {
              name = "${group}.conf";
              value = ''
                [Interface]
                PrivateKey = ''${PRIVATE_KEY}
                Address = ${
                  lib.join "," (
                    lib.filter (ip: ip != null) [
                      spec.gatewayIPv4
                      spec.gatewayIPv6
                    ]
                  )
                }
                ListenPort = ${builtins.toString listenPort}
                PostUp   = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
                PostUp   = ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
                PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
                PostDown = ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

                ${lib.join "\n" (
                  lib.mapAttrsToList (
                    _name:
                    {
                      publicKey,
                      ipv4,
                      ipv6,
                      ...
                    }:
                    ''
                      [Peer]
                      PublicKey = ${publicKey}
                      AllowedIPs = ${
                        lib.join "," (
                          lib.filter (ip: ip != null) [
                            ipv4
                            ipv6
                          ]
                        )
                      }
                    ''
                  ) (lib.filterAttrs (_name: value: value.enable) spec.peers)
                )}
              '';
            }) cfg.groups;
          };
          ciliumNetworkPolicies.world-to-client-vpn = {
            metadata.labels."app.kubernetes.io/name" = "client-vpn";
            spec = {
              endpointSelector.matchLabels."app.kubernetes.io/name" = "client-vpn";
              ingress = [
                {
                  fromEntities = [ "world" ];
                  toPorts = self.lib.toPorts [
                    {
                      port = listenPort;
                      protocol = "UDP";
                    }
                  ];
                }
              ];
              egress = [ { toEntities = [ "world" ]; } ];
            };
          };
          services = lib.mapAttrs' (
            group: spec:
            lib.nameValuePair "${group}-vpn" {
              metadata = {
                labels = labels group // {
                  "cluster.local/ippool" = "routed";
                };
                annotations = {
                  "external-dns.alpha.kubernetes.io/hostname" = "${group}-vpn.${config.homelab.workloads.domain}";
                }
                // lib.optionalAttrs (spec.reservedIPs != [ ]) { "lbipam.cilium.io/ips" = lib.join "," spec.reservedIPs; };
              };
              spec = {
                type = "LoadBalancer";
                selector = labels group;
                ipFamilies = lib.optional ccfg.enableIPv4 "IPv4" ++ lib.optional ccfg.enableIPv6 "IPv6";
                ipFamilyPolicy = lib.mkIf (ccfg.enableIPv4 && ccfg.enableIPv6) "RequireDualStack";
                ports.wg = {
                  port = listenPort;
                  protocol = "UDP";
                };
              };
            }
          ) cfg.groups;
        };
        submodules.instances = lib.mapAttrs' (
          group: spec:
          lib.nameValuePair "${group}-vpn" {
            submodule = "deployment";
            args = {
              inherit (spec) allowEgress;
              ports.wg = {
                containerPort = listenPort;
                protocol = "UDP";
              };
              # The world reaches it through world-to-client-vpn. The policies of policyPorts would select the pods by the
              # instance name, which forcedLabels replaces
              policyPorts = [ ];
              container = {
                image = "${image.buildArgs.name}:${image.imageTag}";
                imagePullPolicy = "Never";
                securityContext = {
                  runAsUser = 0;
                  runAsGroup = 0;
                  # The kernel loads the wireguard module itself on `ip link add`, which only needs NET_ADMIN
                  capabilities.add = [ "NET_ADMIN" ];
                };
                volumeMounts."/etc/wireguard/clients.conf" = {
                  name = "config-tmp";
                  subPath = "clients.conf";
                };
              };
            };
            config.kubernetes.resources.deployments."${group}-vpn" = {
              metadata.labels = forcedLabels group;
              spec.selector.matchLabels = forcedLabels group;
              spec.template.metadata.labels = forcedLabels group;
              spec.template.spec = {
                initContainers.render-config = {
                  image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
                  imagePullPolicy = "Never";
                  args = [
                    ''
                      envsubst \''${PRIVATE_KEY} </config/${group}.conf >/config-tmp/clients.conf
                      chmod 600 /config-tmp/clients.conf
                    ''
                  ];
                  env.PRIVATE_KEY.valueFrom.secretKeyRef = {
                    name = "client-vpn-private-keys";
                    key = group;
                  };
                  securityContext = {
                    runAsUser = 0;
                    runAsGroup = 0;
                    allowPrivilegeEscalation = false;
                    readOnlyRootFilesystem = true;
                    capabilities.drop = [ "ALL" ];
                  };
                  volumeMounts = {
                    "/config".name = "config";
                    "/config-tmp".name = "config-tmp";
                  };
                };
                volumes = {
                  config-tmp.emptyDir.medium = "Memory";
                  config.configMap.name = "client-vpn";
                };
              };
            };
          }
        ) cfg.groups;
      };
    };
  };
}
