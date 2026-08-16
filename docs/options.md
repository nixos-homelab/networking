## homelab\.cilium\.enable



Whether to enable cilium\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.bgp\.enable



Whether to enable the provisioning of Cilium BGP configurations\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/bgp\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/bgp.nix)



## homelab\.cilium\.bgp\.clusterASN

BGP ASN of the cluster



*Type:*
signed integer



*Default:*
` 65000 `

*Declared by:*
 - [nix/modules/cilium/bgp\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/bgp.nix)



## homelab\.cilium\.bgp\.routerASN



BGP ASN of the router



*Type:*
signed integer



*Default:*
` 64512 `

*Declared by:*
 - [nix/modules/cilium/bgp\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/bgp.nix)



## homelab\.cilium\.bgp\.routerIP4



IPv4 of the router for BGP communication



*Type:*
string

*Declared by:*
 - [nix/modules/cilium/bgp\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/bgp.nix)



## homelab\.cilium\.bgp\.routerIP6



IPv6 of the router for BGP communication



*Type:*
string

*Declared by:*
 - [nix/modules/cilium/bgp\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/bgp.nix)



## homelab\.cilium\.cidr-groups\.enable



Whether to enable Cilium\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/cidr-groups\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/cidr-groups.nix)



## homelab\.cilium\.cidr-groups\.localLANCIDR4



IPv4 CIDR of the local LAN



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/cilium/cidr-groups\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/cidr-groups.nix)



## homelab\.cilium\.cidr-groups\.localLANCIDR6



IPv6 CIDR of the local LAN



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/cilium/cidr-groups\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/cidr-groups.nix)



## homelab\.cilium\.extraConfig



Additional Cilium helm configuration values to apply



*Type:*
attribute set of anything



*Default:*
` { } `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.firewall\.enable



Whether to enable the Cilium host firewall (disables the NixOS firewall)\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/firewall\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/firewall.nix)



## homelab\.cilium\.lbIpBlock4\.cidr



IPv4 CIDR for the load balancers



*Type:*
null or string



*Default:*
` "10.44.0.0/16" `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.lbIpBlock4\.start



IP Pool range start for the load balancers



*Type:*
string



*Default:*
` "10.44.0.2" `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.lbIpBlock4\.stop



IP Pool range end for the load balancers



*Type:*
string



*Default:*
` "10.44.0.254" `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.lbIpBlock6\.cidr



IPv6 CIDR for the load balancers



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.lbIpBlock6\.start



IPv6 Pool range start for the load balancers



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.lbIpBlock6\.stop



IPv6 Pool range end for the load balancers



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.masquerade\.enable



Whether to turn on masquerading (automatically turned on if ${config\.homelab\.privacyVPN\.enable} is on)



*Type:*
boolean



*Default:*
` config.homelab.privacyVPN.enable `

*Declared by:*
 - [nix/modules/cilium/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/default.nix)



## homelab\.cilium\.network-policies\.enable



Whether to enable Cilium clusterwide network policies\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/network-policies\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/network-policies.nix)



## homelab\.clientVPN\.enable



Whether to enable the client VPN gateway\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups



VPN client access groups, indexed by group name\. Each group is a wireguard endpoint\.



*Type:*
attribute set of (submodule)

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.allowEgress



List of services this group should be granted access to “gateway” is needed for access to gateway (use e\.g\. \[“gateway” “sabnzbd”] to grant access to sabnzbd only), “cluster” gives full access to the cluster



*Type:*
list of string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.cidr4



IPv4 CIDR of the tunnel



*Type:*
string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.cidr6



IPv6 CIDR of the tunnel



*Type:*
string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.gatewayIPv4



IPv4 of the gateway



*Type:*
string *(read only)*

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.gatewayIPv6



IPv6 of the gateway



*Type:*
string *(read only)*

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.gatewayPublicKey



Public key of the gateway for inline in ready-made client configurations



*Type:*
string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers



VPN Peers in this group



*Type:*
attribute set of (submodule)

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers\.\<name>\.enable



Whether to enable the peer\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers\.\<name>\.config\.enable



Whether to enable the wireguard \& setup-secrets configuration corresponding to this peer, at most one configuration per group can be enabled at the same time\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers\.\<name>\.ipv4



The IPv4 of the peer



*Type:*
null or string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers\.\<name>\.ipv6



The IPv6 of the peer



*Type:*
null or string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.peers\.\<name>\.publicKey



Public key of the peer



*Type:*
string

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.clientVPN\.groups\.\<name>\.reservedIPs



Reserved IPs for the VPN endpoint



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [nix/modules/client-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/client-vpn/default.nix)



## homelab\.cluster\.external-dns\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/external-dns/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/external-dns/default.nix)



## homelab\.homepage\.integrations\.unifi\.enable



integration of Unifi Controller with homepage



*Type:*
boolean



*Default:*
` config.homelab.unifi.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/unifi/homepage\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/unifi/homepage.nix)



## homelab\.netutils\.enable



Whether to enable the netutils debugging container\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/netutils/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/netutils/default.nix)



## homelab\.privacyVPN\.enable



Whether to enable the privacy VPN\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.clientIP4



Internal tunnel IPv4 of the client



*Type:*
null or string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.clientIP6



Internal tunnel IPv6 of the client



*Type:*
null or string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.gatewayAddress



Address for wireguard to connect to



*Type:*
string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.gatewayIP4



Internal tunnel IPv4 of the VPN gateway



*Type:*
null or string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.gatewayIP6



Internal tunnel IPv6 of the VPN gateway



*Type:*
null or string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.privacyVPN\.gatewayPublicKey



Public key of the VPN gateway



*Type:*
string

*Declared by:*
 - [nix/modules/privacy-vpn/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/privacy-vpn/default.nix)



## homelab\.routedIPPool\.enable



Whether to enable the loadbalancer IP pool that is routed to the cluster from the network\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock4\.cidr



IPv4 CIDR



*Type:*
null or string



*Default:*
` "10.45.0.0/16" `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock4\.start



IPv4 Pool range start



*Type:*
string



*Default:*
` "10.45.0.2" `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock4\.stop



IPv4 Pool range end



*Type:*
string



*Default:*
` "10.45.0.254" `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock6\.cidr



IPv6 CIDR



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock6\.start



IPv6 Pool range start



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.routedIPPool\.lbIpBlock6\.stop



IPv6 Pool range end



*Type:*
null or string



*Default:*
` null `

*Declared by:*
 - [nix/modules/routed-ippool/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/routed-ippool/default.nix)



## homelab\.unifi\.enable



Whether to enable Unifi Controller\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/unifi/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/unifi/default.nix)



## homelab\.unifi\.debug



Whether to enable debug mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/unifi/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/unifi/default.nix)



## homelab\.unifi\.reservedIPs



Reserved IPs for the Unifi loadbalancer



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [nix/modules/unifi/default\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/unifi/default.nix)



## kubetree\.cilium\.enable



Whether to enable Cilium CRD transformers\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/cilium/kubetree\.nix](https://github.com/nixos-homelab/networking/blob/main/nix/modules/cilium/kubetree.nix)


