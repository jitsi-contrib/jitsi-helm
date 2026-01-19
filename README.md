# Helm Chart for Jitsi Meet

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/jitsi-meet)](https://artifacthub.io/packages/search?repo=jitsi-meet)
![GitHub Release](https://img.shields.io/github/v/release/jitsi-contrib/jitsi-helm?logo=helm&logoColor=white&label=Latest%20release)
![GitHub Release Date](https://img.shields.io/github/release-date/jitsi-contrib/jitsi-helm?display_date=published_at&logo=git&logoColor=white&label=Released%20at)

[Jitsi-Meet](https://jitsi.org/jitsi-meet/): Secure, simple and scalable video
conferences that you can use as a standalone app or embed in your web
application.

This chart bootstraps a Jitsi Meet stack on Kubernetes.

## Quick start

```bash
helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
helm install myjitsi jitsi/jitsi-meet
```

## Exposing your Jitsi Meet installation

To be able to do video conferencing with other people, the JVB component should
be reachable by all participants (e.g. on a public IP). Thus the default
behaviour of advertised the internal IP of JVB, is not really suitable in many
cases. Kubernetes offers multiple possibilities to work around the problem. Not
all options are available depending on the Kubernetes cluster setup. The chart
tries to make all options available without enforcing one.

### Option 1: Using a LoadBalancer service

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

### Option 2: Using a NodePort service (public node IP or external LB)

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

### Option 3: Using hostPort (public node IP)

```yaml
jvb:
  useHostPort: true

  # Use public IPs of the nodes:
  publicIPs:
    - 30.10.10.1
```

While this allows `jvb.replicaCount` to be greater than 1, it requires exposing
Node IPs and JVB ports directly to Internet.

#### Option 3.1: Using hostPort (auto-detected public node IP)

```yaml
jvb:
  useHostPort: true
  useNodeIP: true
```

This is similar to Option 3, but every JVB pod will auto-detect its own external
IP address based on the node it is running on. This option might be better
suited for installations that use OCTO.

#### Option 3.2: Using hostPort with a port range

```yaml
jvb:
  useHostPort: true
  useNodeIP: true
  UDPPort: 10000
  portRangeSize: 3
```

This is similar to Option 3, but it creates multiple JVB pods using a range of
consecutive ports. For example, these settings create 3 JVB pods using ports
`10000/UDP`, `10001/UDP` and `10002/UDP` respectively.

If `replicaCount` is greater than 1, it creates a total of
`replicaCount * portRangeSize` JVB pods.

### Option 4: Using hostNetwork

```yaml
jvb:
  useHostNetwork: true
```

Similar to Option 3, this way you expose JVB "as is" on the node, without any
additional protection. This is not recommended, but might be useful in some rare
cases.

### Option 4: Using Ingress TCP/UDP forward capabilities

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

### Option 5: Bring your own setup

There are multiple other possibilities combining the available parameters,
depending of your cluster/network setup.

## Recording and streaming support

This chart includes support for _Jibri_, which allows Jitsi Meet users to record
and stream their meetings. To enable Jibri support, add this section to your
`values.yaml`:

```yaml
jibri:
  ## Enabling Jibri will allow users to record
  ## and/or stream their meetings (e.g. to YouTube).
  enabled: true

  ## Enable single-use mode for Jibri (recommended).
  singleUseMode: false

  ## Enable multiple Jibri instances.
  ## Secommended for single-use mode.
  replicaCount: 1

  ## Enable recording service.
  ## Set this to true/false to enable/disable local recordings.
  ## Defaults to enabled (allow local recordings).
  recording: true

  ## Enable livestreaming service.
  ## Set this to true/false to enable/disable live streams.
  ## Defaults to disabled (livestreaming is forbidden).
  livestreaming: true

  ## Enable persistent storage for local recordings.
  ## If disabled, jibri pod will use a transient
  ## emptyDir-backed storage instead.
  persistence:
    enabled: true
    size: 32Gi

  shm:
    ## Set to true to enable "/dev/shm" mount.
    ## May be required by built-in Chromium.
    enabled: true
```

The above example will allow your Jitsi users to make local recordings, as well
as live streams of their meetings.

## Scaling your installation

At the moment you can freely scale Jitsi Web and Jibri pods, as they're
stateless and require zero special configuration to work in multi-instance
setup:

```yaml
web:
  replicaCount: 3

jibri:
  replicaCount: 3
```

Also, this chart supports JVB scaling based on OCTO Relay feature, which allows
different users to connect to different bridges and still see and hear each
other. This feature requires some additional configuration. Here's an example
based on the Option 3.1 mentioned above:

```yaml
jvb:
  ## Set JVB instance count:
  replicaCount: 3
  ## Expose JVB interface port to the outside world
  #  only on nodes that actually have it:
  useHostPort: true
  ## Make every JVB pod announce its Node's external
  #  IP address and nothing more:
  useNodeIP: true

octo:
  ## Enable OCTO support for both JVB and Jicofo:
  enabled: true
```

Please note that the JVB scaling feature is currently under-tested and thus
considered _experimental_. Also note that this chart doesn't allow to scale JVB
into multiple zones/regions yet: all JVB pods will be part of the single OCTO
region named `all`.

## Adding custom Prosody plugins

In case you want to extend your Jitsi Meet installation with additional Prosody
features, you can add custom plugins using additional ConfigMap mounts like
this:

```yaml
prosody:
  extraVolumes:
    - name: prosody-modules
      configMap:
        name: prosody-modules
  extraVolumeMounts:
    - name: prosody-modules
      subPath: mod_measure_client_presence.lua
      mountPath: /prosody-plugins-custom/mod_measure_client_presence.lua
```

No need to add a module from
[jitsi-contrib/prosody-plugins](https://github.com/jitsi-contrib/prosody-plugins)
manually since they are available in the official `jitsi/prosody` container.

## Configuration

Please check [values.yaml](/values.yaml)

## Package

```bash
helm package . -d docs
helm repo index docs --url https://jitsi-contrib.github.io/jitsi-helm/
```
