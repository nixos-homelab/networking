# The networking modules on a one-node cluster under the NixOS test driver, as the manifests check configures them
# (without UniFi, whose mongodb takes hours to build), with a host on the LAN beside it: Cilium brings the node up,
# the VPNs come up without their secrets, the policies let through what they should
{
  self,
  inputs,
  pkgs,
}:
pkgs.testers.runNixOSTest {
  name = "cluster";
  nodes.node =
    { lib, ... }:
    {
      imports =
        lib.attrValues inputs.homelab-shared.nixosModules
        ++ lib.attrValues self.nixosModules
        ++ [
          inputs.homelab-shared.lib.checks.fixture
          ./config.nix
        ];
      networking.hostName = lib.mkForce "node";
      # On a real machine the data directory is a filesystem of its own, which exists before k3s starts
      homelab.k3s.dataDir = lib.mkForce "/var/lib/k3s";
      systemd.tmpfiles.rules = [ "d /var/lib/k3s 0700 root root -" ];
      homelab.unifi.enable = lib.mkForce false;
      # The monitoring stack is monitoring's to test
      homelab.alloy.enable = lib.mkForce false;
      # The test network is the LAN
      homelab.cilium.cidr-groups = {
        localLANCIDR4 = lib.mkForce "192.168.1.0/24";
        localLANCIDR6 = lib.mkForce "2001:db8:1::/64";
      };
      # k3s waits for a default route of each family; the test network has none
      networking.defaultGateway = {
        address = "192.168.1.254";
        interface = "eth1";
      };
      networking.defaultGateway6 = {
        address = "2001:db8:1::fe";
        interface = "eth1";
      };
      virtualisation = {
        memorySize = 6144;
        cores = 3;
        diskSize = 12288;
      };
    };
  nodes.lan =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.netcat ];
      # For the pods allowed to reach the LAN
      networking.firewall.allowedTCPPorts = [ 8000 ];
    };
  testScript = builtins.readFile ./cluster.py;
}
