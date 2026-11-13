{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.homelab.privacy-vpn;
  hllib = inputs.homelab-shared.lib;
  systemd-creds = lib.getExe' pkgs.systemd "systemd-creds";
  credential = "wireguard-privacy-vpn-private-key";
  credstoreKey = "/etc/credstore.encrypted/${credential}";
in
{
  key = "${toString __curPos.file}#modules.nixos.privacy-vpn";
  options.homelab.privacy-vpn = {
    enable = lib.mkEnableOption "the privacy VPN";
    clientIP4 = lib.mkOption {
      description = "Internal tunnel IPv4 of the client";
      type = lib.types.nullOr lib.types.str;
    };
    clientIP6 = lib.mkOption {
      description = "Internal tunnel IPv6 of the client";
      type = lib.types.nullOr lib.types.str;
    };
    gatewayAddress = lib.mkOption {
      description = "Address for wireguard to connect to";
      type = lib.types.str;
    };
    gatewayPublicKey = lib.mkOption {
      description = "Public key of the VPN gateway";
      type = lib.types.str;
    };
    gatewayIP4 = lib.mkOption {
      description = "Internal tunnel IPv4 of the VPN gateway";
      type = lib.types.nullOr lib.types.str;
    };
    gatewayIP6 = lib.mkOption {
      description = "Internal tunnel IPv6 of the VPN gateway";
      type = lib.types.nullOr lib.types.str;
    };
    extraPeerConfig = lib.mkOption {
      description = ''
        Further settings for the gateway's peer, merged into its entry in
        `networking.wireguard.interfaces.privacy-vpn.peers`, which checks them.
      '';
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        persistentKeepalive = 25;
      };
    };
  };
  imports = [ inputs.setup-secrets.nixosModules.default ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.cilium.masquerade.enable;
        message = "In order to use the privacy VPN, masquerading must be enabled (homelab.cluster.masquerade.enable)";
      }
    ];
    homelab.kubernetes.submodules.instances.vpn-egress = {
      submodule = "manifest";
      config.kubernetes.resources.ciliumEgressGatewayPolicies.privacy-vpn = {
        metadata.namespace = null;
        spec = {
          egressGateway = {
            nodeSelector.matchLabels."node-role.kubernetes.io/control-plane" = "true";
            interface = "privacy-vpn";
          };
          selectors = [ { podSelector.matchLabels."cluster.local/egress-gateway" = "privacy-vpn"; } ];
          destinationCIDRs =
            lib.optional (cfg.clientIP4 != null) "0.0.0.0/0" ++ lib.optional (cfg.clientIP6 != null) "::/0";
        };
      };
    };
    networking.wireguard.interfaces.privacy-vpn = {
      ips =
        lib.optional (cfg.clientIP4 != null) "${cfg.clientIP4}/32"
        ++ lib.optional (cfg.clientIP6 != null) "${cfg.clientIP6}/128";
      table = "4242";
      peers = [
        (
          {
            name = "Privacy VPN Gateway";
            endpoint = cfg.gatewayAddress;
            publicKey = cfg.gatewayPublicKey;
            allowedIPs =
              lib.optional (cfg.clientIP4 != null) "0.0.0.0/0" ++ lib.optional (cfg.clientIP6 != null) "::/0";
          }
          // cfg.extraPeerConfig
        )
      ];
      # A credential name, not a path: systemd looks it up in the credstore
      privateKeyFile = credential;
    };
    # nixpkgs loads privateKeyFile with LoadCredential, which doesn't decrypt. The unit lists this after it, so it
    # replaces that entry. A missing key only drops this interface.
    systemd.services.systemd-networkd.serviceConfig.LoadCredentialEncrypted = [ credential ];
    setup-secrets = {
      sources.PRIVACY_VPN_PRIVATE_KEY = {
        description = "Private Key for privacy VPN connection";
        cmd = hllib.setup-secrets.mkScript pkgs "${systemd-creds} decrypt ${credstoreKey} -";
      };
      destinations = [
        {
          logPrefix = "Privacy VPN Private Key";
          requires = [ "PRIVACY_VPN_PRIVATE_KEY" ];
          cmd = hllib.setup-secrets.mkScript pkgs ''
            if [[ ! -e ${credstoreKey} ]] ||
              [[ $(${systemd-creds} decrypt ${credstoreKey} -) != "$PRIVACY_VPN_PRIVATE_KEY" ]]; then
              mkdir -p -m 700 /etc/credstore.encrypted
              printf "%s" "$PRIVACY_VPN_PRIVATE_KEY" |
                ${systemd-creds} encrypt --with-key=tpm2 --name=${credential} - ${credstoreKey}
              # networkd only imports credentials when it starts
              ${lib.getExe' pkgs.systemd "systemctl"} try-restart systemd-networkd.service
            fi
          '';
        }
      ];
    };
    networking.useNetworkd = true; # very much needed for this setup to work in the way it's configured
    systemd.network.networks."40-privacy-vpn" = {
      routingPolicyRules =
        lib.optional (cfg.gatewayIP4 != null) {
          To = "${cfg.gatewayIP4}/32";
          Table = config.networking.wireguard.interfaces.privacy-vpn.table;
        }
        ++ lib.optional (cfg.gatewayIP6 != null) {
          To = "${cfg.gatewayIP6}/128";
          Table = config.networking.wireguard.interfaces.privacy-vpn.table;
        }
        ++ lib.optional (cfg.clientIP4 != null) {
          From = "${cfg.clientIP4}/32";
          Table = config.networking.wireguard.interfaces.privacy-vpn.table;
        }
        ++ lib.optional (cfg.clientIP6 != null) {
          From = "${cfg.clientIP6}/128";
          Table = config.networking.wireguard.interfaces.privacy-vpn.table;
        };
    };
  };
}
