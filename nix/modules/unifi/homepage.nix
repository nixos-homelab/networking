{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.unifi;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.unifi = {
    enable = lib.mkOption {
      description = "integration of Unifi Controller with homepage";
      type = lib.types.bool;
      default = config.homelab.unifi.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.unifi.enable && config.homelab.homepage.enable";
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
    self.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (Unifi credentials)";
        requires = [
          "UNIFI_USERNAME"
          "UNIFI_PASSWORD"
        ];
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret homepage unifi-credentials \
            HOMEPAGE_VAR_UNIFI_USERNAME "''${UNIFI_USERNAME:?}" \
            HOMEPAGE_VAR_UNIFI_PASSWORD "''${UNIFI_PASSWORD:?}"'';
      }
    ];
    homelab.homepage = {
      widgets.unifi_console = {
        enable = lib.mkDefault true;
        settings = {
          type = "unifi_console";
          url = "https://unifi.unifi";
          username = "{{HOMEPAGE_VAR_UNIFI_USERNAME}}";
          password = "{{HOMEPAGE_VAR_UNIFI_PASSWORD}}";
        };
      };
      sections.Networking.enable = lib.mkDefault true;
      services.Networking.unifi = {
        enable = lib.mkDefault true;
        icon = "unifi.png";
        href = "https://unifi.${ccfg.domain}";
        description = "Unifi Controller";
      };
      envFrom = [ { secretRef.name = "unifi-credentials"; } ];
      allowEgress = [ "unifi" ];
    };
  };
}
