# Helm Chart for Jitsi Meet

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/jitsi-meet)](https://artifacthub.io/packages/search?repo=jitsi-meet)
![GitHub Release](https://img.shields.io/github/v/release/jitsi-contrib/jitsi-helm?logo=helm&logoColor=white&label=Latest%20release)
![GitHub Release Date](https://img.shields.io/github/release-date/jitsi-contrib/jitsi-helm?display_date=published_at&logo=git&logoColor=white&label=Released%20at)

- [Quick start](#quick-start)
- [Exposing your Jitsi Meet installation](#exposing-your-jitsi-meet-installation)
- [Recording and streaming support](#recording-and-streaming-support)
- [Transcription support](#transcription-support)
- [Scaling your installation](#scaling-your-installation)
- [Adding custom Prosody plugins](#adding-custom-prosody-plugins)
- [References](#references)

[Jitsi-Meet](https://jitsi.org/jitsi-meet/): Secure, simple and scalable video
conferences that you can use as a standalone app or embed in your web
application.

This chart bootstraps a Jitsi Meet stack on Kubernetes.

See also [jitsi-scaler](https://github.com/jitsi-contrib/jitsi-scaler) for a
Jitsi Meet stack containing multiple shards.

## Quick start

```bash
helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
helm install myjitsi jitsi/jitsi-meet --set publicURL=https://meet.mydomain.com
```

Alternatively, install directly from the OCI registry (GitHub Container
Registry):

```bash
helm install myjitsi oci://ghcr.io/jitsi-contrib/jitsi-meet --set publicURL=https://meet.mydomain.com
```

OCI releases are signed with [cosign](https://github.com/sigstore/cosign)
(keyless). To verify a release before installing:

```bash
cosign verify ghcr.io/jitsi-contrib/jitsi-meet:<version> \
  --certificate-identity-regexp '^https://github.com/jitsi-contrib/jitsi-helm/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Exposing your Jitsi Meet installation

JVB must be reachable by all participants (typically on a public IP), and the
best approach depends on your cluster. The chart supports several options:
LoadBalancer, NodePort, hostPort (including auto-detected node IP and port
ranges), hostNetwork, and ingress TCP/UDP forwarding.

See the [Exposing guide](/docs/guides/exposing.md) for all options and examples.

## Recording and streaming support

Jibri lets Jitsi Meet users record meetings and live-stream them (e.g. to
YouTube). Enable it under the `jibri` key, with options for single-use mode,
multiple instances, local recording, live streaming, and persistent storage.

See the [Recording and streaming guide](/docs/guides/recording.md) for the full
configuration.

## Transcription support

The chart supports near real-time transcription (subtitles) via the Transcriber
(Jigasi in transcriber mode), with a pluggable speech-to-text backend. It has
first-class support for [Skynet](https://github.com/jitsi/skynet) (bundled or
external) and can also use any other Jigasi-supported backend.

See the [Transcription guide](/docs/guides/transcription.md) for setup and
backend options.

## Scaling your installation

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
based on the Option 3.1 mentioned above:

```yaml
jvb:
  # Set JVB instance count:
  replicaCount: 3

  service:
    enabled: false

  # Expose JVB interface port to the outside world
  # only on nodes that actually have it:
  useHostPort: true

  # Make every JVB pod announce its Node's external
  # IP address and nothing more:
  useNodeIP: true

octo:
  # Enable OCTO support for both JVB and Jicofo:
  enabled: true
```

Please note that this chart doesn't allow to scale JVB into multiple
zones/regions yet: all JVB pods will be part of the single OCTO region named
`all`.

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

## References

Feature-specific documentation can be found here:

- [Octo](/docs/guides/testing-octo.md)
- [TURNS](/docs/guides/turns.md)
- [Sample values files](/docs/samples/)

For further documentation on all available configuration, refer to
[values.yaml](/values.yaml).
