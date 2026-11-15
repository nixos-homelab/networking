kubectl = "k3s kubectl"

start_all()

with subtest("networking: without secrets the VPNs have no keys, which only takes down their own interfaces"):
    node.wait_for_unit("systemd-networkd.service")
    node.wait_until_succeeds("ip -4 route show default | grep -q .")
    node.fail("ip link show privacy-vpn")

with subtest("networking: Cilium brings the node up dual-stack and Ready"):
    node.wait_for_unit("k3s.service")
    node.wait_until_succeeds(f"{kubectl} wait node node --for=condition=Ready --timeout=10s", timeout=900)
    node.succeed(f"{kubectl} get node node -o jsonpath='{{.spec.podCIDRs}}' | grep -q :")

with subtest("networking: client-vpn brings up WireGuard without SYS_MODULE"):
    # NixOS loads the module at boot. Without it the pod's `ip link add` has to load it, which needs no capability
    node.succeed("rmmod wireguard")
    node.wait_until_succeeds(f"{kubectl} get namespace client-vpn", timeout=600)
    # Any 32 bytes make a WireGuard private key
    node.succeed(
        f"{kubectl} -n client-vpn create secret generic client-vpn-private-keys"
        " --from-literal=admins=$(head -c 32 /dev/urandom | base64) --dry-run=client -o yaml"
        f" | {kubectl} apply -f -"
    )
    node.wait_until_succeeds(f"{kubectl} -n client-vpn rollout status deploy/admins-vpn --timeout=10s", timeout=600)
    node.succeed(f"{kubectl} -n client-vpn exec deploy/admins-vpn -- wg show clients listen-port | grep -qx 51820")
    node.succeed("test -d /sys/module/wireguard")

# Probe pods in client-vpn's image, for its bash, which as PID 1 ends on SIGTERM only with a trap
image = node.succeed(
    f"{kubectl} -n client-vpn get deploy admins-vpn -o jsonpath='{{.spec.template.spec.containers[0].image}}'"
).strip()
probe = "trap exit TERM; sleep 600 & wait"


def run_probe(name, label):
    node.succeed(
        f"{kubectl} -n default run {name} --image={image} --image-pull-policy=Never"
        f" --labels={label}=allow --command -- bash -c '{probe}'"
    )
    node.wait_until_succeeds(f"{kubectl} -n default wait pod/{name} --for=condition=Ready --timeout=10s", timeout=120)


with subtest("networking: cluster-wide policies: one object per name, pod-to-local-lan allows egress to the LAN"):
    # The deploy controller applies the policies' manifest only once Cilium has made its CRDs, a pass or more after the
    # first; before that no policy denies anything, and the probe below would pass without one
    node.wait_until_succeeds(
        f"{kubectl} get ccnp pod-to-apiserver -o jsonpath='{{.spec.egress}}' | grep -q kube-apiserver", timeout=300
    )
    lan.succeed("(nc -lk 8000 >/dev/null 2>&1 &)")
    lan_ip = lan.succeed("ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1").strip()
    run_probe("lan-probe", "cluster.local/local-lan-egress")
    node.wait_until_succeeds(
        f"{kubectl} -n default exec lan-probe -- timeout 3 bash -c 'exec 3<>/dev/tcp/{lan_ip}/8000'", timeout=60
    )

with subtest("networking: pods with metrics-server's egress label reach k3s' bundled metrics-server"):
    # The apiserver comes from the host, which Cilium lets in regardless; pods get through only when the netpols select
    # the bundled pods
    node.wait_until_succeeds(f"{kubectl} -n kube-system rollout status deploy/metrics-server --timeout=10s", timeout=300)
    ms = node.succeed(
        f"{kubectl} -n kube-system get pod -l k8s-app=metrics-server -o jsonpath='{{.items[0].status.podIP}}'"
    ).strip()
    run_probe("metrics-probe", "cluster.local/metrics-server-egress")
    node.wait_until_succeeds(
        f"{kubectl} -n default exec metrics-probe -- timeout 3 bash -c 'exec 3<>/dev/tcp/{ms}/10250'", timeout=60
    )
