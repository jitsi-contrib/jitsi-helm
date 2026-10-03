# Upgrading

## Chart version vs app version

`Chart.yaml` carries two version fields:

- `version` - the chart's own version, bumped on any chart change.
- `appVersion` - the default image tag used for Jitsi's own components (web,
  prosody, jvb, jicofo, jigasi, transcriber, jibri) when their `image.tag` is
  not set.

Third-party components (coturn, etherpad, excalidraw, ...), Skynet and the Opus
transcriber proxy are pinned to their own `image.tag` in `values.yaml`,
independently of `appVersion`.

## Before upgrading

- Review the `values.yaml` differences between your current version and the
  target version - defaults and available options can change between releases.
- Re-check your own overrides against the new defaults.
- Back up any persistent data (PVC-backed volumes, e.g. jibri recordings, or an
  external database if you use one) before a major version bump, in case the new
  app version migrates its on-disk format.

## Performing the upgrade

```bash
helm repo update
helm upgrade myjitsi jitsi/jitsi-meet -f my-values.yaml
```

Or from the OCI registry:

```bash
helm upgrade myjitsi oci://ghcr.io/jitsi-contrib/jitsi-meet -f my-values.yaml
```

A config change rolls the affected pods automatically: the chart adds a checksum
of each component's config to its pod template, so pods restart when their
ConfigMap or Secret changes during the upgrade.

## Breaking change in the default resources

Every component now has default resource requests and a memory limit, where
`resources` used to be empty. There is no CPU limit on purpose.

| Component                   | CPU request | Memory request | Memory limit |
| --------------------------- | ----------- | -------------- | ------------ |
| web, coturn                 | 100m        | 32Mi           | 1Gi          |
| prosody                     | 100m        | 64Mi           | 2Gi          |
| opusTranscriberProxy        | 100m        | 128Mi          | 2Gi          |
| excalidraw                  | 100m        | 256Mi          | 2Gi          |
| jicofo, jigasi, transcriber | 100m        | 384Mi          | 4Gi          |
| etherpad                    | 100m        | 512Mi          | 2Gi          |
| jvb                         | 100m        | 512Mi          | 4Gi          |
| jibri                       | 100m        | 1Gi            | 8Gi          |
| skynet                      | 100m        | 1Gi            | 8Gi          |

Helm merges your values with these defaults key by key. If you set only part of
`resources`, the missing keys now come from the defaults. `resources: {}` does
not remove them, `resources: null` does.

Check the following before upgrading:

- **A raised Java heap.** The 4Gi limit fits the default 3 GiB heap of jicofo,
  jvb, jigasi and transcriber. If you raised `JICOFO_MAX_MEMORY`,
  `VIDEOBRIDGE_MAX_MEMORY` or `JIGASI_MAX_MEMORY`, raise `limits.memory` too, to
  about the heap plus 1Gi. Otherwise the pod is OOM-killed under load, not at
  upgrade time.
- **A memory request above the new limit.** If you set `requests.memory` but no
  `limits.memory`, and your request is above the default limit, Kubernetes
  rejects the pod. Set `limits.memory` as well.
- **A LimitRange in the namespace.** Its `max`, `min` or `maxLimitRequestRatio`
  now applies to these values instead of filling in its own defaults. Set values
  within its rules, or `resources: null`.
- **A ResourceQuota on `limits.memory`.** The core components alone now count
  11Gi per release. Each extra jvb adds 4Gi and each jibri 8Gi, so with
  autoscaling or several jibris a quota can quietly stop new pods. Raise the
  quota or lower the limits.

## Breaking change in the coTURN ports

`coturn.service.ports.turn` now defaults to **443** (was 3478). Port 3478 is
blocked on most restricted networks, which is exactly where TURN is needed, and
Chrome refuses TURN on any port other than 53, 80, 443 or 1024 and above. Plain
TURN and TURNS now share one public port, so a firewall request is a single
line: allow outbound access to the TURN host on 443.

Before upgrading, make sure 443 is open to the coTURN Service IP. To keep the
old public port instead:

```yaml
coturn:
  service:
    ports:
      turn: 3478
```

Inside the container coTURN now listens on **3478 only**. The TLS listener
shares that port rather than binding 5349, because coTURN recognises TLS from
the first bytes of a TCP connection and serves plain TURN and TURNS on the same
socket. Anything addressing the pod directly on 5349 - a NetworkPolicy, a custom
Service or a scrape config - must be updated.

`coturn.turn.transport` now takes a comma separated list, so plain TURN can be
offered over both transports:

```yaml
coturn:
  turn:
    transport: "udp,tcp"
```

The default is still `udp` alone, so a plain TURN install keeps a single
protocol Service. Offering both transports, or offering `udp` together with
`turns.enabled`, needs a LoadBalancer that carries TCP and UDP in one Service.
See the [TURN guide](/docs/guides/turns.md) for which implementations can.

Prosody no longer advertises a `stun:` URL when `udp` is not offered. The STUN
entry is always UDP, so with `transport: "tcp"` it pointed at a port nothing
answered on.

## Breaking change in the web Service port

`web.service.port` now defaults to **8000** (was 80), matching the port the web
container listens on. Every other component already publishes its container port
on the Service, and the mismatch on web was a frequent source of confusion.

Nothing changes inside the pod: the container still listens on 8000 and the
Service still targets it by the port name `http`.

The chart's own Ingress and Gateway resources follow `web.service.port`, so they
keep working. Update anything outside the chart that addresses the web Service
on port 80:

- an Ingress, HTTPRoute or backend config you manage yourself,
- a parent chart or service mesh route pointing at the Service,
- probes, scrape configs or NetworkPolicies using the Service port,
- `kubectl port-forward svc/<release>-web 8080:80`.

To keep the old port, set it explicitly:

```yaml
web:
  service:
    port: 80
```

## Breaking changes when running multiple JVBs behind a service

`jvb.portRangeSize` is no longer limited to `useHostPort`. It now works with the
JVB Service too: each JVB gets its own port and the same Service publishes all
of them, so a single LoadBalancer IP serves every JVB. See the
[Scaling guide](/docs/guides/scaling.md).

- JVB's UDP container port is now named **`rtp-udp-0`** (was `rtp-udp`), and one
  port is named per JVB. The JVB Service targets them by name, which is what
  lets a single Service publish several JVBs. Update anything that refers to the
  old name, such as a NetworkPolicy using named ports.
- If you set `portRangeSize` greater than 1 **without** `useHostPort`, the value
  used to be ignored and you got a single JVB. It is now honoured, so you will
  get that many JVBs, pods and Service ports.
- `jvb.replicaCount` greater than 1 without `useHostPort` or `useHostNetwork`
  now **fails** the render instead of deploying. All pods of a deployment are
  reachable on the same Service port, so traffic could arrive at the wrong JVB.
  Use `portRangeSize`, or keep `replicaCount` with `useHostPort` or
  `useHostNetwork`, where each pod is reachable on its own node IP.
- With a NodePort Service, `nodePort` is the base of a consecutive range. Keep
  it equal to `UDPPort` so the advertised and the reachable port match.

## Breaking changes in the hardened series

This series switches to the hardened Jitsi images and makes the secure settings
the default. Review all of the following before upgrading.

### Images

- Jitsi images now come from `ghcr.io/jitsi/*` instead of Docker Hub. If you pin
  `image.tag` with a digest, refresh those digests against ghcr.io - Docker Hub
  digests do not resolve there.
- The minimum app version is `stable-11146-1`. Older tags do not support the
  read-only root filesystem this chart now configures.

### Hardened by default

The Jitsi components and coturn now run as UID 1000 with a read-only root
filesystem and dropped capabilities. The third-party images (etherpad,
excalidraw, Skynet, the Opus transcriber proxy) get only the image-agnostic part
of it. See the [security guide](/docs/guides/security.md) for the full picture
and how to relax it.

- PVC-backed volumes (prosody, jibri, transcriber) are made writable through
  `fsGroup: 1000`. If your storage class ignores `fsGroup`, you may need
  `fsGroupChangePolicy`.

### Changed paths

- Prosody's data path moved from `/config/data` to `/var/lib/prosody`, and
  `prosody.dataDir` was removed. The same PVC is reused, but Prosody now keeps
  its data in the `data` subfolder of the mount point, one level below where 2.x
  stored it. Service accounts re-register themselves. If you store user accounts
  in Prosody (`internal_hashed`), back the volume up before upgrading, then move
  the existing content into `data/`.
- Jibri recordings moved from `/data/recordings` to `/storage/recordings`.
- `jibri.shm.enabled` now defaults to `true`, and jibri no longer requests the
  `SYS_ADMIN` capability.

### Changed ports

- The web container listens on **8000** (was 80). The Service published 80 and
  mapped to it, so Ingress and Gateway users were unaffected. Anything targeting
  the pod directly - a custom Service, NetworkPolicy or scrape config - must be
  updated. The Service port itself changed later, see
  [the web Service port](#breaking-change-in-the-web-service-port).
- `web.httpsEnabled` was **removed**. Terminate TLS at your ingress, gateway or
  external load balancer.
- coTURN listens on fixed ports inside the container. The Service maps the
  public ports to those, so `coturn.service.ports.turn` and
  `coturn.service.ports.turns` now set only the _Service_ port; the container
  ports no longer follow them. The container ports changed later, see
  [the coTURN ports](#breaking-change-in-the-coturn-ports).

### Removed

- Colibri WebSockets were removed from Jitsi in `stable-11146`, so
  `websockets.colibri` was removed from the chart. JVB signalling uses SCTP data
  channels. An existing values file that still sets it is ignored rather than
  rejected.
- `jibri.livenessProbeOverride` and `jibri.readinessProbeOverride`. They were
  never listed in `values.yaml` and only ever shadowed `jibri.livenessProbe` /
  `jibri.readinessProbe`, which is where a probe belongs. Move any value you set
  there onto the plain key.

## Deprecations

- Jigasi-based transcription (the path the Transcriber and Skynet use) is
  deprecated upstream and will be removed in a future Jitsi release. The
  successor is the bridge-based path, which this chart supports through
  `opusTranscriberProxy`. Existing Transcriber and Skynet setups keep working
  for now, but new deployments should start on the new path. See the
  [custom AI service guide](/docs/guides/opus-transcriber-proxy-custom-ai.md).
