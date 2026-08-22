# Security hardening

Since the `stable-11146` images, all Jitsi components run as a non-root user
with a read-only root filesystem, and this chart applies that by default. No
configuration is needed to get it.

## What the defaults are

Every hardened component gets:

```yaml
podSecurityContext:
  fsGroup: 1000
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  privileged: false
  readOnlyRootFilesystem: true
  runAsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
```

The containers write only to the paths the chart mounts for them (`/run`,
`/tmp`, and a few component-specific ones). `fsGroup` is what makes a
PersistentVolumeClaim writable by the container user.

`runAsUser` and `runAsGroup` match the `s6` user of the Jitsi images, which is
1000:1000. The jvb metrics sidecar is the one exception - it uses 10001, because
its image expects that UID.

## What is covered

- web, prosody, jicofo, jvb, jigasi, transcriber, jibri (and their init
  containers)
- coturn, including its `init-coturn` and `acme-proxy` init containers
- the metrics sidecars (prosody, jicofo, jvb)

These pods satisfy the Pod Security Admission `restricted` profile.

## What is not covered

Etherpad, Excalidraw, Skynet and the Opus transcriber proxy are third-party
images. They get the image-agnostic half of the hardening -
`allowPrivilegeEscalation: false`, `privileged: false`, all capabilities
dropped, `seccompProfile: RuntimeDefault` - but not the identity or filesystem
half, so they do not satisfy `restricted` as shipped:

- Etherpad and Skynet run as their image's own user (5001 and 1001).
- Excalidraw and the Opus transcriber proxy run as **root**.
- None of them sets `readOnlyRootFilesystem`.
- Skynet is the only one with a `podSecurityContext`: `fsGroup: 1001`, which is
  what makes its models PVC writable.

All of it is configurable through their own `securityContext` /
`podSecurityContext` values. `docs/samples/values-hardened.yaml` has worked
examples for Etherpad and Excalidraw, including the volumes each of them needs
to run non-root.

Containers you supply yourself, through `<component>.extraInitContainers` or
`web.extraContainers`, are rendered as written. The chart adds no
`securityContext` to them, so the `restricted` claim above covers chart-owned
containers only.

## ServiceAccount tokens

No pod mounts a ServiceAccount token. Nothing in the chart talks to the
Kubernetes API, so every workload sets `automountServiceAccountToken: false`.

If you add a sidecar, an extra container or a hook that does need the API,
enable it for that component alone:

```yaml
jvb:
  automountServiceAccountToken: true
```

It is a per-component value on purpose: all components share one ServiceAccount,
so any RBAC bound to it is reachable from every pod that mounts a token. Setting
it to `null` omits the field and falls back to the ServiceAccount default.

## One thing worth knowing

**Do not relax `allowPrivilegeEscalation`.** It looks like a setting to loosen
when something breaks, but it is required. The images ship a setgid
`s6-overlay-suexec`; with `allowPrivilegeEscalation: false` the kernel sets
`no_new_privs` and the setgid bit is ignored, which is what lets s6 run
unprivileged. Setting it to `true` re-enables the setgid bit, s6 then attempts
`setgid(0)`, and the container dies with:

```
s6-overlay-suexec: fatal: unable to setgid to root: Operation not permitted
```

## Privileged ports

A non-root container cannot bind a port below 1024, and `capabilities.add` does
not change that: Kubernetes does not set _ambient_ capabilities, so a capability
is dropped when the entrypoint `exec`s. The chart therefore listens on
unprivileged ports inside the container and lets the Service map the public port
to it - for example web listens on 8000 behind a Service on 80, and coTURN
listens on 5349 behind a Service on 443.

If you expose a component with `hostNetwork` or `hostPort`, there is no Service
doing that translation, so a public port below 1024 would need `runAsUser: 0`
for that component.

Note that coTURN still sets `capabilities.add: [NET_BIND_SERVICE]`, for an
unrelated reason: the `turnserver` binary carries that capability as a _file_
capability, and under `no_new_privs` the kernel refuses to execute such a binary
unless the process already holds it.

## Relaxing the defaults

Every setting above is an ordinary value, so it can be overridden per component:

```yaml
jibri:
  securityContext:
    readOnlyRootFilesystem: false
```

If a component fails to start with a message like
`FATAL ERROR: <path> is not writable by the container user`, it needs a writable
path that the chart does not mount. To find it, run that component with
`readOnlyRootFilesystem: false` and look for recent writes outside the mounted
volumes:

```bash
kubectl exec <pod> -- sh -c 'find / -xdev -mmin -60 2>/dev/null | grep -vE "^/(proc|sys|dev)"'
```

`-xdev` keeps the search on the root filesystem, so anything it lists is exactly
what read-only mode blocks. Mount an emptyDir there via `extraVolumes` /
`extraVolumeMounts`, or open an issue so it can be added to the chart.
