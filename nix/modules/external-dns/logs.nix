# How external-dns' logs are parsed: logrus logfmt and client-go's klog in both instances, Go's log with a level in the
# libdns webhook
{ inputs, ... }:
{ ... }:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = {
    homelab.alloy.logs.pods = {
      external-dns = {
        format = "go";
        examples = [
          {
            lines = [
              ''time="2026-11-18T17:15:54Z" level=debug msg="Overriding existing TTL 0 with new value 300 for endpoint prowlarr.thehub.lol"''
              ''I1118 21:59:04.065508       1 warnings.go:107] "Warning: The v1alpha2 version of TLSRoute has been deprecated and will be removed in a future release of the API. Please upgrade to v1."''
              ''E1118 21:50:55.498775       1 reflector.go:204] "Failed to watch" err="apiserver not ready" logger="UnhandledError" type="*v1.Ingress"''
            ];
            expect = [
              {
                message = "Overriding existing TTL 0 with new value 300 for endpoint prowlarr.thehub.lol";
                level = "debug";
              }
              {
                message = "Warning: The v1alpha2 version of TLSRoute has been deprecated and will be removed in a future release of the API. Please upgrade to v1.";
                level = "info";
                fields.caller = "warnings.go:107";
              }
              {
                message = "Failed to watch";
                level = "error";
                fields = {
                  caller = "reflector.go:204";
                  error = "apiserver not ready";
                  component = "UnhandledError";
                };
              }
            ];
          }
        ];
      };
      external-dns-node-source = {
        namespace = "external-dns";
        format = "go";
      };
      external-dns-libdns-webhook = {
        namespace = "external-dns";
        format = "golog";
        examples = [
          {
            # With the newline the API server hands each line over with
            lines = [
              "2026/11/18 07:22:06 INFO Setting log level level=INFO\n"
              "2026/11/18 21:52:03 INFO Updating records zone=thehub.lol records=\"[{Name:nas TTL:5m0s ProviderData:<nil>}]\"\n"
            ];
            expect = [
              {
                message = "Setting log level level=INFO";
                level = "info";
              }
              {
                message = "Updating records zone=thehub.lol records=\"[{Name:nas TTL:5m0s ProviderData:<nil>}]\"";
                level = "info";
              }
            ];
          }
        ];
      };
    };
  };
}
