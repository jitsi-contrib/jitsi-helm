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
