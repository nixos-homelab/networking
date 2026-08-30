{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  # See https://github.com/NixOS/nixpkgs/blob/597283ad8aa0b331c788e97c4c262d58877074ef/nixos/modules/services/networking/unifi.nix
  ccfg = config.homelab.cluster;
  cfg = config.homelab.unifi;
  hllib = inputs.homelab-shared.lib;
  jrePkg = pkgs.jdk25_headless;
  mongodb-7_0 =
    (import inputs.nixpkgs-mongodb-pin {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfreePredicate = config.nixpkgs.config.allowUnfreePredicate;
    }).mongodb-7_0;
  unifiPkg = pkgs.stdenvNoCC.mkDerivation {
    name = "mk-unifi-home";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir $out
      cp -r ${pkgs.unifi}/* $out/
      ln -s "${mongodb-7_0}/bin" $out/bin
      ln -s /var/lib/unifi/data $out/data
      ln -s /var/lib/unifi/logs $out/logs
      ln -s /var/lib/unifi/run $out/run
      runHook postInstall
    '';
  };
  run = pkgs.writeShellScriptBin "unifi" ''
    exec "${jrePkg}/bin/java" \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.base/java.time=ALL-UNNAMED \
    --add-opens=java.base/sun.security.util=ALL-UNNAMED \
    --add-opens=java.base/java.io=ALL-UNNAMED \
    --add-opens=java.rmi/sun.rmi.transport=ALL-UNNAMED \
    -jar "${unifiPkg}/lib/ace.jar" "$@"
  '';
  image = pkgs.dockerTools.buildLayeredImage {
    name = "cluster.local/unifi";
    contents = [
      pkgs.bash
      mongodb-7_0
      run
    ]
    ++ lib.optionals cfg.debug ccfg.debugTools;
    config.Entrypoint = [
      (lib.getExe pkgs.tini)
      (lib.getExe run)
      "--"
    ];
    config.Cmd = [ "start" ];
  };
in
{
  key = "${toString __curPos.file}#modules.nixos.unifi";
  options.homelab.unifi = {
    enable = lib.mkEnableOption "Unifi Controller";
    debug = lib.mkEnableOption "debug mode";
    reservedIPs = lib.mkOption {
      description = "Reserved IPs for the Unifi loadbalancer";
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
  imports = [ self.nixosModules.routed-ippool ] ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.postgresql.enable;
        message = "Unifi depends on the routed loadbalancer IP Pool module. Enable with `homelab.routed-ippool = { enable=true; lbIpBlock4.cidr = ...; }`";
      }
    ];
    services.k3s.images = [ image ];
    homelab.cluster.backup.volumes.unifi.unifi = [ "/backup" ];
    setup-secrets = {
      sources = {
        UNIFI_USERNAME = {
          description = "Unifi username (readonly)";
          cmd = hllib.setup-secrets.mkScript pkgs "getKubeSecret unifi unifi-credentials username";
        };
        UNIFI_PASSWORD = {
          description = "Unifi password (readonly)";
          cmd = hllib.setup-secrets.mkScript pkgs "getKubeSecret unifi unifi-credentials password";
        };
      };
      destinations = [
        {
          logPrefix = "Unifi credentials";
          requires = [
            "UNIFI_USERNAME"
            "UNIFI_PASSWORD"
          ];
          cmd = hllib.setup-secrets.mkScript pkgs ''
            setKubeSecret unifi unifi-credentials \
              username "''${UNIFI_USERNAME:?}" \
              password "''${UNIFI_PASSWORD:?}"'';
        }
      ];
    };
    kubetree.resources.unifi = {
      certificate = {
        apiVersion = "cert-manager.io/v1";
        kind = "Certificate";
        metadata = {
          namespace = "unifi";
          name = "unifi";
          labels."app.kubernetes.io/name" = "unifi";
        };
        spec = {
          secretName = "unifi-tls";
          commonName = "unifi.${ccfg.domain}";
          dnsNames = [ "unifi.${ccfg.domain}" ];
          issuerRef = {
            group = "cert-manager.io";
            kind = "ClusterIssuer";
            name = config.kubetree.workload-macros.acmeProvider;
          };
        };
      };
      service = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          namespace = "unifi";
          name = "unifi";
          labels = {
            "app.kubernetes.io/name" = "unifi";
            "cluster.local/ippool" = "routed";
          };
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = "unifi.${ccfg.domain}";
          }
          // lib.optionalAttrs (builtins.length cfg.reservedIPs > 0) ({
            "lbipam.cilium.io/ips" = lib.join "," cfg.reservedIPs;
          });
        };
        spec = {
          type = "LoadBalancer";
          selector."app.kubernetes.io/name" = "unifi";
          ipFamilies = (lib.optional ccfg.enableIPv4 "IPv4") ++ (lib.optional ccfg.enableIPv6 "IPv6");
          portsByName = {
            web = {
              port = 443;
              targetPort = 8443;
            };
            inform = 8080;
            portalredir = 8880;
            portalredir-tls = 8843;
            speed-test = 6789;
            stun = {
              port = 3478;
              targetPort = 3478;
              protocol = "UDP";
            };
            discovery = {
              port = 10001;
              targetPort = 10001;
              protocol = "UDP";
            };
          };
        }
        // (lib.optionalAttrs (ccfg.enableIPv4 && ccfg.enableIPv6) {
          ipFamilyPolicy = "RequireDualStack";
        });
      };
      netpols = {
        apiVersion = "cluster.local";
        kind = "NetpolMacro";
        metadata.name = "unifi";
        spec.ports = [ 8443 ];
      };
      macro = {
        apiVersion = "cluster.local";
        kind = "WorkloadMacro";
        metadata.name = "unifi";
        spec = {
          allowIngress = [
            "local-lan"
          ];
          allowEgress = [
            "local-lan"
            "internet"
          ];
          dataPath = "/var/lib/unifi/data";
          podSpecMacro = {
            initContainersByName.ln-keystore = {
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
              command = [
                "/bin/bash"
                "-c"
              ];
              args = [
                ''
                  mkdir -p /var/lib/unifi/data/db
                  unifi import_key_cert /tls/tls.key /tls/tls.crt
                ''
              ];
              securityContext.readOnlyRootFilesystem = true;
              volumeMountsByPath = {
                "/var/lib/unifi/data" = "data";
                "/tls" = "tls";
                "/var/lib/unifi/logs" = {
                  name = "data";
                  subPath = "logs";
                };
                "/var/lib/unifi/run" = {
                  name = "tmp";
                  subPath = "run";
                };
                "/tmp" = {
                  name = "tmp";
                  subPath = "tmp";
                };
              };
            };
            mainContainer = {
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
              workingDir = "/var/lib/unifi";
              portsByName = {
                web = 8443;
                inform = 8080;
                portalredir = 8880;
                portalredir-tls = 8843;
                speed-test = 6789;
                stun = {
                  containerPort = 3478;
                  protocol = "UDP";
                };
                discovery = {
                  containerPort = 10001;
                  protocol = "UDP";
                };
              };
              volumeMountsByPath = {
                "/var/lib/unifi/logs" = {
                  name = "data";
                  subPath = "logs";
                };
                "/var/lib/unifi/run" = {
                  name = "tmp";
                  subPath = "run";
                };
                "/tmp" = {
                  name = "tmp";
                  subPath = "tmp";
                };
              };
            };
            volumesByName = {
              tmp.emptyDir = { };
              tls.secret.secretName = "unifi-tls";
            };
          };
        };
      };
    };
  };
}
