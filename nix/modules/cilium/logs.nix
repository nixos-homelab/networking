# How Cilium's logs are parsed: slog logfmt in the agent and the operator, its module the component
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.cilium.enable {
    homelab.alloy.logs.pods = {
      cilium-agent = {
        namespace = "cilium";
        format = "logfmt";
        examples = [
          {
            lines = [
              ''time=2026-11-18T12:35:01.020046686Z level=info msg="Program attached to device using tcx" module=agent.datapath.loader progName=cil_from_container device=lxca82ca05215fa''
            ];
            expect = [
              {
                message = "Program attached to device using tcx";
                level = "info";
                program = "cilium-agent";
                service_name = "cilium-agent";
                fields.component = "agent.datapath.loader";
              }
            ];
          }
        ];
      };
      cilium-operator = {
        namespace = "cilium";
        format = "logfmt";
      };
    };
  };
}
