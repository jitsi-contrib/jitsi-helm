# Scaling your installation

At the moment you can freely scale Jitsi Web, Jibri and Coturn pods, as they're
stateless and require zero special configuration to work in multi-instance
setup:

```yaml
web:
  replicaCount: 3

coturn:
  replicaCount: 3

jibri:
  replicaCount: 3
```

Also, this chart supports JVB scaling based on OCTO Relay feature, which allows
different users to connect to different bridges and still see and hear each
other. This feature requires some additional configuration. Here's an example
based on the Option 3.1 mentioned in the
[Exposing guide](/docs/guides/exposing.md):

```yaml
jvb:
  # Set JVB instance count:
  replicaCount: 3

  service:
    enabled: false

  # Expose JVB interface port to the outside world
  # only on nodes that actually have it:
  useHostPort: true

  # Make every JVB pod announce the address of the
  # node it runs on:
  useNodeIP: true

  # Let every JVB pod find its external IP address
  # through STUN:
  stunServers: "meet-jit-si-turnrelay.jitsi.net:443"

octo:
  # Enable OCTO support for both JVB and Jicofo:
  enabled: true
```

Please note that this chart doesn't allow to scale JVB into multiple
zones/regions yet: all JVB pods will be part of the single OCTO region named
`all`.

## Scaling JVB behind a service

The example above disables the JVB service and exposes the pods on their nodes.
If you keep the service enabled, scale with `portRangeSize` instead: it deploys
one JVB per port, and the same service publishes all of them.

```yaml
jvb:
  # 3 JVBs, listening on 10000/UDP, 10001/UDP and 10002/UDP
  UDPPort: 10000
  portRangeSize: 3

  service:
    type: LoadBalancer

octo:
  enabled: true
```

`replicaCount` cannot be used for this: all pods of a deployment are reachable
on the same service port, so the chart rejects a value greater than 1 while the
service is enabled. See the [Exposing guide](/docs/guides/exposing.md) for the
LoadBalancer and NodePort variants.

## Autoscaling JVB

`jvb.autoscaling` creates a HorizontalPodAutoscaler per `portRangeSize` index.
It requires `useHostPort` or `useHostNetwork`.

```yaml
jvb:
  useHostPort: true
  useNodeIP: true

  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4

octo:
  enabled: true
```

`replicaCount` is ignored while this is enabled. `minReplicas` and `maxReplicas`
count per port, so `portRangeSize: 3` with `maxReplicas: 4` allows up to 12
bridges.

`maxReplicas` cannot usefully exceed the number of schedulable nodes. A node
carries one JVB per port, so anything above that stays `Pending`.

Enable `octo` as well, otherwise a new bridge only takes new meetings and cannot
relieve one that is already busy.

### Choosing the target

The default scales on CPU per bridge and needs metrics-server, which is not
installed on every cluster. To find the right number, put one bridge under the
load you care about and watch:

```bash
kubectl exec <jvb-pod> -c jitsi-meet -- \
  sh -c 'curl -s localhost:8080/colibri/stats | jq "{stress_level, participants}"'

kubectl top pods -l app.kubernetes.io/component=jvb
```

Take the CPU where `stress_level` reaches 0.8, the point a bridge counts as
overloaded, and set the target a little below it. Measure with your real codec
and simulcast settings: an audio-only room costs a fraction of a video one.

## Draining a JVB before it is removed

Where the chart creates no service - `useHostPort`, `useHostNetwork` or
`service.enabled: false` - a pod drains before it goes away. It stops taking new
meetings and stays alive until the ones on it end, so scaling in costs no calls.
Pods behind a service are not drained.

`jvb.terminationGracePeriodSeconds` caps the wait. When it expires the pod is
killed and whatever is still on it drops, so it has to cover a whole meeting.

A draining pod holds its node port until it finishes, so its replacement is not
scheduled on that node before then. With a single bridge the wait lasts until a
gap between meetings.

On uninstall a draining pod can outlive the rest of the release. If one lingers:

```bash
kubectl delete pod -l app.kubernetes.io/component=jvb --grace-period=0 --force
```

## Testing OCTO

When OCTO is enabled, the participants of a single meeting are distributed
across multiple JVBs if the number of participants exceeds a threshold.

```yaml
octo:
  enabled: true
```

The default threshold is 80. You can lower this value for a quick test in a test
deployment.

```yaml
jicofo:
  extraEnvs:
    MAX_BRIDGE_PARTICIPANTS: "3"
```

In this case, the participants will be distributed across multiple JVBs if there
are more than 3 participants in the meeting. Join the same meeting using
multiple browser tabs and check the server count which shows the number of JVBs
hosting this meeting. It should be greater than 1.

![OCTO server count](/docs/files/octo-server-count.png)
