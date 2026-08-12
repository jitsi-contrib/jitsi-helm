# Upgrading

## Chart version vs app version

`Chart.yaml` carries two version fields:

- `version` - the chart's own version, bumped on any chart change.
- `appVersion` - the default image tag used for Jitsi's own components (web,
  prosody, jvb, jicofo, jigasi, jibri) when their `image.tag` is not set.

Third-party components (coturn, etherpad, excalidraw, ...) and Skynet are pinned
to their own `image.tag` in `values.yaml`, independently of `appVersion`.

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
- `jvb.replicaCount` greater than 1 while the JVB Service is enabled now
  **fails** the render instead of deploying. All pods of a deployment are
  reachable on the same Service port, so traffic could arrive at the wrong JVB.
  Use `portRangeSize`, or keep `replicaCount` with `useHostPort`, where each pod
  is reachable on its own node IP.
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

All components now run as UID 1000 with a read-only root filesystem and dropped
capabilities. See the [security guide](/docs/guides/security.md) for the full
picture and how to relax it.

- PVC-backed volumes (prosody, jibri, transcriber) are made writable through
  `fsGroup: 1000`. If your storage class ignores `fsGroup`, you may need
  `fsGroupChangePolicy`.
- Prosody gains a short-lived root init container (`chown-data`) that fixes the
  ownership of its data volume.

### Changed paths

- Prosody's data path moved from `/config/data` to `/var/lib/prosody`, and
  `prosody.dataDir` was removed. The same PVC is reused and only its mount path
  changes, so the data should carry over. If you store user accounts in Prosody
  (`internal_hashed`), back the volume up before upgrading.
- Jibri recordings moved from `/data/recordings` to `/storage/recordings`.
- `jibri.shm.enabled` now defaults to `true`, and jibri no longer requests the
  `SYS_ADMIN` capability.

### Changed ports

- The web container listens on **8000** (was 80). The Service still publishes 80
  and maps to it, so Ingress and Gateway users are unaffected. Anything
  targeting the pod directly - a custom Service, NetworkPolicy or scrape config
  - must be updated.
- `web.httpsEnabled` was **removed**. Terminate TLS at your ingress, gateway or
  external load balancer.
- coTURN listens on **3478** and **5349** inside the container. The Service maps
  the public ports to those, so `coturn.service.ports.turn` and
  `coturn.service.ports.turns` now set only the _Service_ port; the container
  ports no longer follow them.

### Removed

- Colibri WebSockets were removed from Jitsi in `stable-11146`, so
  `websockets.colibri` was removed from the chart. JVB signalling uses SCTP data
  channels. An existing values file that still sets it is ignored rather than
  rejected.
- `prosody.dataDir` and `web.httpsEnabled`, as noted above.
- `jibri.livenessProbeOverride` and `jibri.readinessProbeOverride`. They were
  never listed in `values.yaml` and only ever shadowed `jibri.livenessProbe` /
  `jibri.readinessProbe`, which is where a probe belongs. Move any value you set
  there onto the plain key.

## Deprecations

- Jigasi-based transcription (the path the Transcriber and Skynet use) is
  deprecated upstream and will be removed in a future Jitsi release. The
  successor is a bridge-based transcription architecture. Existing Transcriber
  and Skynet setups keep working for now; plan to migrate once this chart adds
  support for the new path.
