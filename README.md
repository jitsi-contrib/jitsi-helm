# Helm Chart for Jitsi Meet

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/jitsi-meet)](https://artifacthub.io/packages/search?repo=jitsi-meet)
![GitHub Release](https://img.shields.io/github/v/release/jitsi-contrib/jitsi-helm?logo=helm&logoColor=white&label=Latest%20release)
![GitHub Release Date](https://img.shields.io/github/release-date/jitsi-contrib/jitsi-helm?display_date=published_at&logo=git&logoColor=white&label=Released%20at)

- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Exposing your Jitsi Meet installation](#exposing-your-jitsi-meet-installation)
- [Recording and streaming support](#recording-and-streaming-support)
- [Transcription support](#transcription-support)
- [Scaling your installation](#scaling-your-installation)
- [Adding custom Prosody plugins](#adding-custom-prosody-plugins)
- [Documentation](#documentation)

[Jitsi-Meet](https://jitsi.org/jitsi-meet/): Secure, simple and scalable video
conferences that you can use as a standalone app or embed in your web
application.

This chart bootstraps a Jitsi Meet stack on Kubernetes.

See also [jitsi-scaler](https://github.com/jitsi-contrib/jitsi-scaler) for a
Jitsi Meet stack containing multiple shards.

## Prerequisites

- A Kubernetes cluster and Helm 3.8+ (3.8+ is required for the OCI install).
- A way to expose JVB media to participants (see the Exposing section below).
- cert-manager, only if you enable TURNS (see the TURNS guide under
  Documentation).

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

Jitsi Web, Jibri, and Coturn are stateless and scale freely via `replicaCount`.
JVB scales via the OCTO relay feature, which spreads the participants of one
meeting across multiple bridges.

See the [Scaling guide](/docs/guides/scaling.md) for replica settings, the OCTO
configuration, and how to test it.

## Adding custom Prosody plugins

Extend Prosody with extra plugins by mounting them via `prosody.extraVolumes` /
`extraVolumeMounts`. Modules from the jitsi-contrib/prosody-plugins collection
already ship in the official `ghcr.io/jitsi/prosody` image.

See the [Prosody plugins guide](/docs/guides/prosody-plugins.md) for an example.

## Documentation

Each feature section above links to its detailed guide. See also:

- [TURNS (TURN over TLS)](/docs/guides/turns.md)
- [Security hardening](/docs/guides/security.md)
- [Troubleshooting](/docs/guides/troubleshooting.md)
- [Upgrading](/docs/guides/upgrading.md)
- [Sample values files](/docs/samples/)
- [All guides](/docs/guides/)

For the full configuration reference, see [values.yaml](/values.yaml).
