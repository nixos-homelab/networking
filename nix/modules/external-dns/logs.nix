# How external-dns' logs are parsed: logrus logfmt in both instances, Go's log with a level in the libdns webhook
{ inputs, ... }:
{ ... }:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = {
    homelab.alloy.logs.pods = {
      external-dns = {
        format = "logfmt";
        examples = [
          {
            lines = [
              ''time="2026-11-18T17:15:54Z" level=debug msg="Overriding existing TTL 0 with new value 300 for endpoint prowlarr.thehub.lol"''
            ];
            expect = [
              {
                message = "Overriding existing TTL 0 with new value 300 for endpoint prowlarr.thehub.lol";
                level = "debug";
              }
            ];
          }
        ];
      };
      external-dns-node-source = {
        namespace = "external-dns";
        format = "logfmt";
      };
      external-dns-libdns-webhook = {
        namespace = "external-dns";
        format = "golog";
        examples = [
          {
            lines = [ "2026/11/18 07:22:06 INFO Setting log level level=INFO" ];
            expect = [
              {
                message = "Setting log level level=INFO";
                level = "info";
              }
            ];
          }
        ];
      };
    };
  };
}
