# Exposing your Jitsi Meet installation

To be able to do video conferencing with other people, the JVB component should
be reachable by all participants (e.g. on a public IP). Thus the default
behaviour of advertised the internal IP of JVB, is not really suitable in many
cases. Kubernetes offers multiple possibilities to work around the problem. Not
all options are available depending on the Kubernetes cluster setup. The chart
tries to make all options available without enforcing one.

## Option 1: Using a LoadBalancer service

This requires a cloud environment that supports LoadBalancer provisioning. It
can be enabled in the values:

```yaml
jvb:
  service:
    type: LoadBalancer

  # Depending on the cloud, LB's public IP cannot be known in advances.
  # So, deploy first, without the next option.
  # Next: redeploy with the following option, set to the public IP you retrieved
  # from the API.
  # Additionally, you can add your cluster's public IPs if you want to use
  # direct connection as a fallback.
  publicIPs:
    - 1.2.3.4
    # - 30.10.10.1
    # - 30.10.10.2
```

In this configuration, `jvb.replicaCount` must remain at 1. Increasing the
replicas will cause UDP packets to be routed to random JVB instances, breaking
the video connection.

### Option 1.1: Multiple JVBs sharing public IPs via per-instance LoadBalancer services

If you have far fewer public IPs than JVBs you want to run, you can put
several JVBs behind the same public IP, each on its own UDP port. Every JVB
still gets its own single-pod `LoadBalancer` Service; Services that land on
the same public IP share it via your LoadBalancer implementation's IP-sharing
annotations.

```yaml
octo:
  enabled: true

jvb:
  replicaCount: 1 # must stay 1: one pod per instance

  publicIPs:
    - 1.2.3.4
    - 5.6.7.8
  portsPerIP: 3 # -> 6 bridges: <ip>:10000, <ip>:10001, <ip>:10002
  UDPPort: 10000
  disableStun: true # IPs are explicit; STUN would only report the node's egress IP

  service:
    enabled: true
    perInstanceServices: true
    type: LoadBalancer
    externalTrafficPolicy: Cluster # required, see below
```

This creates `len(publicIPs) * portsPerIP` JVB instances (6, in the example
above): `jvb-0`..`jvb-2` behind `1.2.3.4` on ports `10000`-`10002`, `jvb-3`..
`jvb-5` behind `5.6.7.8` on the same three ports. See
[the sample config](/docs/samples/values-shared-ip-matrix.yaml).

Important caveats:

- **This only works with a LoadBalancer implementation that supports sharing
  one IP across several Services**: MetalLB, Cilium LB-IPAM, kube-vip, loxilb.
  **Cloud-provider NLBs (AWS, GCP, Azure, DigitalOcean) do not support this**
  — each `LoadBalancer` Service there gets its own address, which is the
  opposite of the goal. On such clouds, use Option 3/3.1/3.2 (hostPort) with
  your own external LB or DNAT in front instead.
- There is no advertise-*port* override in the Jitsi images: JVB always
  advertises the port it binds. `Service.port`, the container port and
  `JVB_PORT` are therefore always equal, and there is no way to remap an
  external port to a different internal one.
- Because each Service in a sharing group selects a different pod, MetalLB
  requires `externalTrafficPolicy: Cluster` for the group (it only allows
  `Local` when all sharing Services select the *same* pods). This adds a hop
  and SNATs media to the node IP, which is harmless for JVB, but the node's
  conntrack tables and any firewall in front must allow the whole
  `UDPPort..UDPPort+portsPerIP-1` range on **every** advertised IP.
- Don't set `jvb.service.extraPorts` in this mode: a duplicate port on any
  Service breaks the whole IP-sharing group. Rely on the pod's
  `readinessProbe` instead.
- Treat `jvb.publicIPs` as append-only: reordering it re-maps every instance
  to a different IP and rewrites every Service, causing a full media outage.
- Deployments update with `strategy: Recreate`, so upgrading a JVB briefly
  drops its Service to zero endpoints. Jicofo re-invites affected conferences
  to another bridge.

## Option 2: Using a NodePort service (public node IP or external LB)

```yaml
jvb:
  service:
    type: NodePort

  # Set the following variables if you want to use a specific external port for
  # the service. The default is to select a random port from Kubelet's allowed
  # NodePort range (30000-32767).
  #UDPPort: 32000
  #nodePort: 32000

  # Use public IP of the node or the external LB:
  publicIPs:
    - 30.10.10.1
```

In this configuration, `jvb.replicaCount` must remain at 1. Increasing the
replicas will cause UDP packets to be routed to random JVB instances, breaking
the video connection.

## Option 3: Using hostPort (public node IP)

```yaml
jvb:
  service:
    enabled: false

  # Use public IPs of the nodes:
  publicIPs:
    - 30.10.10.1

  useHostPort: true
  UDPPort: 10000
```

While this allows `jvb.replicaCount` to be greater than 1, it requires exposing
Node IPs and JVB ports directly to Internet.

### Option 3.1: Using hostPort (auto-detected public node IP)

```yaml
jvb:
  service:
    enabled: false

  useNodeIP: true

  useHostPort: true
  UDPPort: 10000
```

This is similar to Option 3, but every JVB pod will auto-detect its own external
IP address based on the node it is running on. This option might be better
suited for installations that use OCTO.

### Option 3.2: Using hostPort with a port range

```yaml
jvb:
  service:
    enabled: false

  useNodeIP: true

  useHostPort: true
  UDPPort: 10000
  portRangeSize: 3
```

This is similar to Option 3, but it creates multiple JVB pods using a range of
consecutive ports. For example, these settings create 3 JVB pods using ports
`10000/UDP`, `10001/UDP` and `10002/UDP` respectively.

If `replicaCount` is greater than 1, it creates a total of
`replicaCount * portRangeSize` JVB pods.

See [the sample config](/docs/samples/values-hostport-range.yaml)

## Option 4: Using hostNetwork

```yaml
jvb:
  useHostNetwork: true
```

Similar to Option 3, this way you expose JVB "as is" on the node, without any
additional protection. This is not recommended, but might be useful in some rare
cases.

## Option 5: Using Ingress TCP/UDP forward capabilities

In case of an ingress capable of doing TCP/UDP forwarding (like nginx-ingress),
it can be setup to forward the video streams.

```yaml
# Don't forget to configure the ingress properly (separate configuration)
jvb:
  # 1.2.3.4 being one of the IP of the ingress controller
  publicIPs:
    - 1.2.3.4
```

Again in this case, only one JVB will work.

## Option 6: Bring your own setup

There are multiple other possibilities combining the available parameters,
depending of your cluster/network setup.
