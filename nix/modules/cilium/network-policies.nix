{ self, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.cilium.network-policies;
  enable = config.homelab.cilium.enable && cfg.enable;
in
{
  options.homelab.cilium.network-policies = {
    enable = lib.mkEnableOption "Cilium clusterwide network policies";
  };
  config = {
    homelab.kubernetes.submodules.instances.networkpolicies = lib.mkIf enable {
      submodule = "manifest";
      config.kubernetes.resources = {
        ciliumClusterwideNetworkPolicies = {
          deny-all = {
            metadata.namespace = null;
            spec.endpointSelector = { };
            spec.ingress = [ { fromEntities = [ ]; } ];
            spec.egress = [ { toEntities = [ ]; } ];
          };
          pod-to-coredns = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels = { };
            spec.egress = [
              {
                toEndpoints = [
                  {
                    matchLabels = {
                      "k8s:io.kubernetes.pod.namespace" = "kube-system";
                      k8s-app = "kube-dns";
                    };
                  }
                ];
                toPorts = self.lib.toPorts [
                  {
                    port = 53;
                    protocol = "UDP";
                  }
                  {
                    port = 53;
                    protocol = "TCP";
                  }
                ];
              }
            ];
          };
          pod-to-apiserver = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/apiserver-egress" = "allow";
            spec.egress = [ { toEntities = [ "kube-apiserver" ]; } ];
          };
          pod-to-internet = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/internet-egress" = "allow";
            spec.egress = [ { toEntities = [ "world" ]; } ];
          };
          pod-from-internet = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/internet-ingress" = "allow";
            spec.ingress = [ { fromEntities = [ "world" ]; } ];
          };
          pod-to-gateway = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/gateway-egress" = "allow";
            spec.egress = [ { toEntities = [ "ingress" ]; } ];
          };
          gateway-from-pod = {
            metadata.namespace = null;
            spec.endpointSelector.matchExpressions = [
              {
                key = "reserved:ingress";
                operator = "Exists";
              }
            ];
            spec.ingress = [
              {
                fromEndpoints = [
                  {
                    matchExpressions = [
                      {
                        key = "k8s:io.kubernetes.pod.namespace";
                        operator = "Exists";
                      }
                      {
                        key = "cluster.local/gateway-egress";
                        operator = "In";
                        values = [ "allow" ];
                      }
                    ];
                  }
                ];
              }
            ];
          };
          gateway-to-pod = {
            metadata.namespace = null;
            spec.endpointSelector.matchExpressions = [
              {
                key = "reserved:ingress";
                operator = "Exists";
              }
            ];
            spec.egress = [
              {
                toEndpoints = [
                  {
                    matchExpressions = [
                      {
                        key = "k8s:io.kubernetes.pod.namespace";
                        operator = "Exists";
                      }
                      {
                        key = "cluster.local/gateway-ingress";
                        operator = "In";
                        values = [ "allow" ];
                      }
                    ];
                  }
                ];
              }
            ];
          };
          pod-from-gateway = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/gateway-ingress" = "allow";
            spec.ingress = [ { fromEntities = [ "ingress" ]; } ];
          };
          pod-to-cluster = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/cluster-egress" = "allow";
            spec.egress = [ { toEntities = [ "cluster" ]; } ];
          };
          cluster-from-pod = {
            metadata.namespace = null;
            spec.endpointSelector = { };
            spec.ingress = [
              {
                fromEndpoints = [
                  {
                    matchExpressions = [
                      {
                        "key" = "k8s:io.kubernetes.pod.namespace";
                        "operator" = "Exists";
                      }
                      {
                        key = "cluster.local/cluster-egress";
                        operator = "In";
                        values = [ "allow" ];
                      }
                    ];
                  }
                ];
              }
            ];
          };
          pod-from-local-lan = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/local-lan-ingress" = "allow";
            spec.ingress = [ { fromCIDRSet = [ { cidrGroupRef = "local-lan"; } ]; } ];
          };
          pod-to-local-lan = {
            metadata.namespace = null;
            spec.endpointSelector.matchLabels."cluster.local/local-lan-egress" = "allow";
            spec.egress = [ { toCIDRSet = [ { cidrGroupRef = "local-lan"; } ]; } ];
          };
        };
        ciliumNetworkPolicies = {
          coredns-from-pod = {
            metadata.namespace = "kube-system";
            spec.endpointSelector.matchLabels.k8s-app = "kube-dns";
            spec.ingress = [
              {
                fromEntities = [
                  "host"
                  "remote-node"
                  "kube-apiserver"
                  "cluster"
                ];
                toPorts = self.lib.toPorts [
                  {
                    port = 53;
                    protocol = "TCP";
                  }
                  {
                    port = 53;
                    protocol = "UDP";
                  }
                ];
              }
            ];
            spec.egress = [
              {
                toEntities = [ "world" ];
                toPorts = self.lib.toPorts [
                  {
                    port = 53;
                    protocol = "UDP";
                  }
                  {
                    port = 53;
                    protocol = "TCP";
                  }
                ];
              }
              { toEntities = [ "kube-apiserver" ]; }
            ];
          };
          # The metrics-server the runner bundles, unless a module deploys one: to the kubelets for the metrics and to
          # the API server. Who may reach it comes from the policy intent the runner states for it
          metrics-server-egress = lib.mkIf (!lib.elem "metrics-server" config.homelab.cluster.providedComponents) {
            metadata.namespace = "kube-system";
            spec.endpointSelector.matchLabels.k8s-app = "metrics-server";
            spec.egress = [
              {
                toEntities = [
                  "host"
                  "remote-node"
                ];
                toPorts = self.lib.toPorts [ 10250 ];
              }
              { toEntities = [ "kube-apiserver" ]; }
            ];
          };
        };
      };
    };
  };
}
