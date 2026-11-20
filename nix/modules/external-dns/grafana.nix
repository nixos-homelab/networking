# The external-dns module's namespace in the `network` area of the Home dashboard, whose CPU, memory and traffic graphs
# sum the containers by area
{ inputs, ... }:
_:
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  config.homelab.grafana.home.areas.network = {
    color = "#ff9830";
    namespaces = [ "external-dns" ];
  };
}
