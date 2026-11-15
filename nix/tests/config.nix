# The networking modules set up on the shared checks' fixture: dual-stack Cilium with its firewall and policies, the
# routed pool, both VPNs, UniFi and homepage. Addresses from the documentation ranges, keys all zero. The manifests check
# evaluates it; the cluster test boots it, without UniFi
{ ... }:
let
  prefix6 = "2001:db8:0:1";
  key = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
in
{
  homelab = {
    cluster = {
      enableIPv6 = true;
      podCidr6 = "${prefix6}:0:42::/96";
      svcCidr6 = "${prefix6}:0:43::/112";
    };
    cilium = {
      enable = true;
      firewall.enable = true;
      lbIpBlock6.cidr = "${prefix6}:0:44::/112";
      cidr-groups = {
        enable = true;
        localLANCIDR4 = "192.0.2.0/24";
        localLANCIDR6 = "2001:db8:0:2::/64";
      };
      network-policies.enable = true;
    };
    routed-ippool = {
      enable = true;
      lbIpBlock6.cidr = "${prefix6}:0:45::/112";
    };
    unifi = {
      enable = true;
      reservedIPs = [
        "10.45.0.3"
        "${prefix6}:0:45:0:3"
      ];
    };
    client-vpn = {
      enable = true;
      groups.admins = {
        allowEgress = [ "cluster" ];
        reservedIPs = [
          "10.45.0.2"
          "${prefix6}:0:45:0:2"
        ];
        cidr4 = "10.16.189.0/24";
        gatewayIPv4 = "10.16.189.1/24";
        cidr6 = "fd00:1::/48";
        gatewayIPv6 = "fd00:1::1/48";
        gatewayPublicKey = key;
        peers.laptop = {
          enable = true;
          ipv4 = "10.16.189.2/32";
          ipv6 = "fd00:1::2/128";
          publicKey = key;
        };
      };
    };
    privacy-vpn = {
      enable = true;
      gatewayAddress = "[2001:db8:0:3::10]:51820";
      gatewayPublicKey = key;
      clientIP4 = "10.2.0.2";
      clientIP6 = "fd00:2::2";
      gatewayIP4 = "10.2.0.1";
      gatewayIP6 = "fd00:2::1";
    };
    homepage.enable = true;
  };
}
