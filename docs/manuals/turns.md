# TURNS (TURN over TLS on TCP/443)

Optionally, TURNS can be activated. This enables clients in restricted networks,
for example behind tight NAT's, to connect to meetings over TCP/443 with TLS,
when they would otherwise fail to connect over UDP. Clients with working UDP
connections will not be affected. TURNS is provided as a fallback when P2P or
Direct-to-JVB is unavailable/fails.

## Prerequisites

Enabling TURNS requires the following conditions to be satisfied:

- cert-manager installed in the cluster
- Kubernetes v1.28+ if using `acmeProxy`
- A working `ClusterIssuer` or `Issuer`
- `turnHost` to be set, and DNS to be pointing at the exposed coTURN Service IP
- Optional: Reloader for automatic certificate rotation

## Configuration

An example configuration for enabling TURNS could be:

```
coturn:
  enabled: true # enable standard TURN
  replicaCount: 3

  turns:
    enabled: true # activate TURNS
    certificate:

      # create TLS certificates using cert-manager
      create: true

      # use the given issuer to produce certificates
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
        group: cert-manager.io

      # enable proxying of ACME challenge requests back to the `traefik` service
      # in the `traefik` namespace
      acmeProxy:
        enabled: true
        target: traefik.traefik.svc.cluster.local
```

The above configuration will activate TURNS. It will extend coTURN with a small
sidecar that proxies ACME challenge requests to the defined ingress - in this
case, Traefik - to enable certificate validation. If you have Reloader available
in the cluster, the coTURN pods will automatically reload when the certificate
changes.

## Architecture

The TURNS implementation in this chart relies entirely on internal relays. When
TURNS is enabled, a single Service of type LoadBalancer exposes TCP/443 for
client communications, and TCP/80 for certificate renewals. All
`coTURN <-> peer (JVB)` communication happens internally in the cluster.

## TLS Certificates

TLS certificates for client communication can be provided by setting
`coturn.turns.certificate.existingSecretName`, which should be a secret
containing keys `tls.crt` and `tls.key`. Alternatively, certificates can be
auto-created if `cert-manager` and a working `ClusterIssuer` or `Issuer` is
available. In the latter case, enabling `coturn.turns.acmeProxy` is required, as
ACME will be handled by whatever ingress is associated with your `Issuer` or
`ClusterIssuer`, but the external certificate authority will be sending ACME
validation requests to the IP associated with the domain set in `turnHost`, and
these requests have to be proxied back to the targeted ingress. When using
`coturn.turns.certificate.create`, it is recommended to have Reloader available,
to ensure pods load new certificates when they are refreshed.

## Allowed peers

To ensure that coTURN is able to relay traffic to your JVB's, you should ensure
that the ClusterIP ranges your JVB's (the "peer") is running on is covered by
the range(s) defined in `coturn.allowedPeerIp`. When TURNS is enabled, this is
by default set to `10.244.0.0-10.244.255.255`. This value accepts either a
single range in the format seen here, or a list of ranges in the same format.

## Relay port ranges

Relays provided by coTURN open a range of ports (internally). Each client
connected via TURNS is allocated to at least one UDP port - meaning the
theoretical maximum number of concurrent TURNS clients follows the formula:
`replica count * ports in range`. The default should be more than enough - but
this is a knob to turn in very demanding, high-traffic installations serving
many restricted clients. In all practicality, you are likely to hit bandwidth or
resource limits before having to extend this range, even with a single replica.
