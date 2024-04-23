# Helm Chart for Jitsi Meet

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/jitsi-meet)](https://artifacthub.io/packages/search?repo=jitsi-meet) ![GitHub Release](https://img.shields.io/github/v/release/jitsi-contrib/jitsi-helm?logo=helm&logoColor=white&label=Latest%20release)
 ![GitHub Release Date](https://img.shields.io/github/release-date/jitsi-contrib/jitsi-helm?display_date=published_at&logo=git&logoColor=white&label=Released%20at)


[jitsi-meet](https://jitsi.org/jitsi-meet/) Secure, Simple and Scalable Video
Conferences that you use as a standalone app or embed in your web application.

## TL;DR;

```bash
helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
helm install myjitsi jitsi/jitsi-meet
```

## Introduction

This chart bootstraps a jitsi-meet deployment, like the official
[one](https://meet.jit.si).

## Exposing your Jitsi Meet installation

To be able to do video conferencing with other people, the JVB component should
be reachable by all participants (e.g. on a public IP). Thus the default
behaviour of advertised the internal IP of JVB, is not really suitable in many
cases. Kubernetes offers multiple possibilities to work around the problem. Not
all options are available depending on the Kubernetes cluster setup. The chart
tries to make all options available without enforcing one.

### Option 1: service of type `LoadBalancer`

This requires a cloud setup that enables a Loadbalancer attachement.
This could be enabled via values:

```yaml
jvb:
  service:
    type: LoadBalancer

  # Depending on the cloud, LB's public IP cannot be known in advance, so deploy first, without the next option.
  # Next: redeploy with the following option set to the public IP you retrieved from the API.
  # Additionally, you can add your cluster's public IPs if you want to use direct connection as a fallback.
  publicIPs:
    - 1.2.3.4
    # - 30.10.10.1
    # - 30.10.10.2
```

In this case you're not allowed to change the `jvb.replicaCount` to more than
`1`, UDP packets will be routed to random `jvb`, which would not allow for a
working video setup.

### Option 2: NodePort and node with Public IP or external loadbalancer

```yaml
jvb:
  service:
    type: NodePort
  # Set the following variable if you want to use a specific external port for the service.
  # The default is to select a random port from Kubelet's allowed NodePort range (30000-32767).

  # nodePort: 10000

  # Use public IP of one (or more) of your nodes,
  # or the public IP of an external LB:
  publicIPs:
    - 30.10.10.1
```

In this case you're not allowed to change the `jvb.replicaCount` to more than
`1`, UDP packets will be routed to random `jvb`, which would not allow for a
working video setup.

### Option 3: hostPort and node with Public IP

```yaml
jvb:
  useHostPort: true
  # Use public IP of one (or more) of your nodes,
  # or the public IP of an external LB:
  publicIPs:
    - 30.10.10.1
```

In this case you can have more the one `jvb` but you're putting you cluster at
risk by having the nodes IPs and JVB ports directly exposed on the Internet.

#### Option 3.1: hostPort and auto-detected Node IP

```yaml
jvb:
  useHostPort: true
  useNodeIP: true
```

This is similar to option 3, but every JVB pod will auto-detect it's own
external IP address based on the node it's running on. This option might be
better suited for installations that use OCTO.

### Option 4: hostNetwork

```yaml
jvb:
  useHostNetwork: true
```

Similar to Option 3, this way you expose JVB "as is" on the node, without any
additional protection. This is not recommended, but might be useful in some rare
cases.

### Option 4: Use ingress TCP/UDP forward capabilities

In case of an ingress capable of doing tcp/udp forwarding (like nginx-ingress),
it can be setup to forward the video streams.

```yaml
# Don't forget to configure the ingress properly (separate configuration)
jvb:
  # 1.2.3.4 being one of the IP of the ingress controller
  publicIPs:
    - 1.2.3.4

```

Again in this case, only one jvb will work in this case.

### Option 5: Bring your own setup

There are multiple other possibilities combining the available parameters, depending of your cluster/network setup.


## Recording and streaming support

This chart includes support for *Jibri*, which allows Jitsi Meet users to record and stream their meetings.
To enable Jibri support, add this section to your `values.yaml`:
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
considered *experimental*. Also note that this chart doesn't allow to scale JVB
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

## Configuration

The following table lists the configurable parameters of the jisti-meet chart and their default values.

Parameter | Description | Default
--- | --- | ---
`imagePullSecrets` | List of names of secrets resources containing private registry credentials | `[]`
`enableAuth` | Enable authentication | `false`
`enableGuests` | Enable guest access | `true`
`websockets.colibri.enabled` | Enable WebSocket support for JVB/Colibri | `false`
`websockets.xmpp.enabled` | Enable WebSocket support for Prosody/XMPP | `false`
`jibri.enabled` | Enable Jibri service | `false`
`jibri.useExternalJibri` | Use external Jibri service, instead of chart-provided one | `false`
`jibri.singleUseMode` | Enable Jibri single-use mode | `false`
`jibri.recording` | Enable local recording service | `true`
`jibri.livestreaming` | Enable livestreaming service | `false`
`jibri.persistence.enabled` | Enable persistent storage for Jibri recordings | `false`
`jibri.persistence.size` | Jibri persistent storage size | `4Gi`
`jibri.persistence.existingClaim` | Use pre-created PVC for Jibri | `(unset)`
`jibri.persistence.storageClassName` | StorageClass to use with Jibri | `(unset)`
`jibri.shm.enabled` | Allocate shared memory to Jibri pod | `false`
`jibri.shm.useHost` | Pass `/dev/shm` from host to Jibri | `false`
`jibri.shm.size` | Jibri shared memory size | `256Mi`
`jibri.replicaCount` | Number of replica of the jibri pods | `1`
`jibri.image.repository` | Name of the image to use for the jibri pods | `jitsi/jibri`
`jibri.extraEnvs` | Map containing additional environment variables for jibri | `{}`
`jibri.livenessProbe` | Map that holds the liveness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A livenessProbe map
`jibri.readinessProbe` | Map that holds the readiness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A readinessProbe map
`jibri.breweryMuc` | Name of the XMPP MUC used by jibri | `jibribrewery`
`jibri.xmpp.user` | Name of the XMPP user used by jibri to authenticate | `jibri`
`jibri.xmpp.password` | Password used by jibri to authenticate on the XMPP service | 10 random chars
`jibri.recorder.user` | Name of the XMPP user used by jibri to record | `recorder`
`jibri.recorder.password` | Password used by jibri to record on the XMPP service | 10 random chars
`jibri.strategy` | Depolyment update strategy and parameters | `(unset)`
`jigasi.enabled` | Enable Jigasi service | `false`
`jigasi.useExternalJigasi` | Use external Jigasi service, instead of chart-provided one | `false`
`jigasi.replicaCount` | Number of replica of the Jigasi pods | `1`
`jigasi.image.repository` | Name of the image to use for the Jigasi pods | `jitsi/jigasi`
`jigasi.breweryMuc` | Name of the XMPP MUC used by Jigasi | `jigasibrewery`
`jigasi.xmpp.user` | Name of the XMPP user used by Jigasi to authenticate | `jigasi`
`jigasi.xmpp.password` | Password used by Jigasi to authenticate on the XMPP service | 10 random chars
`jigasi.livenessProbe` | Map that holds the liveness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A livenessProbe map
`jigasi.readinessProbe` | Map that holds the readiness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A readinessProbe map
`jigasi.extraEnvs` | Map containing additional environment variables for Jigasi | `{}`
`jicofo.replicaCount` | Number of replica of the jicofo pods | `1`
`jicofo.image.repository` | Name of the image to use for the jicofo pods | `jitsi/jicofo`
`jicofo.extraEnvs` | Map containing additional environment variables for jicofo | `{}`
`jicofo.livenessProbe` | Map that holds the liveness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A livenessProbe map
`jicofo.readinessProbe` | Map that holds the readiness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A readinessProbe map
`jicofo.xmpp.password` | Password used by jicofo to authenticate on the XMPP service | 10 random chars
`jicofo.xmpp.componentSecret` | Values of the secret used by jicofo for the xmpp-component | 10 random chars
`jvb.publicIPs` | List of IP addresses for JVB to announce to clients | `(unset)`
`jvb.useNodeIP` | Auto-detect external IP address based on the Node IP | `false`
`jvb.stunServers` | List of STUN/TURN servers to announce to the users | `meet-jit-si-turnrelay.jitsi.net:443`
`jvb.service.enabled` | Boolean to enable os disable the jvb service creation | `false` if `jvb.useHostPort` is `true` otherwise `true`
`jvb.service.type` | Type of the jvb service | `ClusterIP`
`jvb.service.annotations` | Additional annotations for JVB service (might be useful for managed k8s) | `{}`
`jvb.service.extraPorts` | Additional ports to expose from your JVB pod(s) | `[]`
`jvb.UDPPort` | UDP port used by jvb, also affects port of service, and hostPort | `10000`
`jvb.nodePort` | UDP port used by NodePort service | `(unset)`
`jvb.useHostPort` | Enable HostPort feature (may not work on some CNI plugins) | `false`
`jvb.useHostNetwork` | Connect JVB pod to host network namespace | `false`
`jvb.extraEnvs` | Map containing additional environment variables to jvb | `{}`
`jvb.xmpp.user` | Name of the XMPP user used by jvb to authenticate | `jvb`
`jvb.xmpp.password` | Password used by jvb to authenticate on the XMPP service | 10 random chars
`jvb.livenessProbe` | Map that holds the liveness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A livenessProbe map
`jvb.readinessProbe` | Map that holds the readiness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A readinessProbe map
`jvb.metrics.enabled` | Boolean that control the metrics exporter for jvb. If true the `ServiceMonitor` will also created | `false`
`jvb.metrics.prometheusAnnotations` | Boolean that controls the generation of prometheus annotations, to expose metrics for HPA | `false`
`jvb.metrics.image.repository` | Default image repository for metrics exporter | `docker.io/systemli/prometheus-jitsi-meet-exporter`
`jvb.metrics.image.tag` | Default tag for metrics exporter | `1.1.5`
`jvb.metrics.image.pullPolicy` | ImagePullPolicy for metrics exporter | `IfNotPresent`
`jvb.metrics.serviceMonitor.enabled` | `ServiceMonitor` for Prometheus | `true`
`jvb.metrics.serviceMonitor.selector` | Selector for `ServiceMonitor` | `{ release: prometheus-operator }`
`jvb.metrics.serviceMonitor.interval` | Interval for `ServiceMonitor` | `10s`
`jvb.metrics.serviceMonitor.honorLabels` | Make `ServiceMonitor` honor labels | `false`
`jvb.metrics.resources` | Resources for the metrics container | `{ requests: { cpu: 10m, memory: 16Mi }, limits: { cpu: 20m, memory: 32Mi } }`
`octo.enabled` | Boolean to enable or disable the OCTO mode, for a single region | `false`
`web.httpsEnabled` | Boolean that enabled tls-termination on the web pods. Useful if you expose the UI via a `Loadbalancer` IP instead of an ingress | `false`
`web.httpRedirect` | Boolean that enabled http-to-https redirection. Useful for ingress that don't support this feature (ex: GKE ingress) | `false`
`web.resolverIP` | Override nameserver IP for Web container | (*unset*, use auto-detected nameserver IP)
`web.extraEnvs` | Map containing additional environment variable to web pods | `{}`
`web.livenessProbe` | Map that holds the liveness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A livenessProbe map
`web.readinessProbe` | Map that holds the readiness probe, you can add parameters such as timeout or retries following the Kubernetes spec | A readinessProbe map
`tz` | System Time Zone | `Europe/Amsterdam`

## Package

```bash
helm package . -d docs
helm repo index docs --url https://jitsi-contrib.github.io/jitsi-helm/
```
