# TURN and TURNS on port 443

Jitsi already encrypts the media with DTLS-SRTP, so TURN is not there to make
the media safer. It is there to get it through firewalls. That is why the chart
puts everything on port 443: it is the one port restricted networks reliably
leave open and Chrome refuses TURN on any port other than 53, 80, 443 or 1024
and above.

It also makes the request to a partner company a single line: allow outbound
access to `turn.example.com` on 443.

## Fallback levels

A client tries these in order and only falls back when the level above fails:

1. Direct UDP to the videobridge on its port. Most participants end here.
2. Plain TURN over UDP/443. For networks that block the JVB port but allow UDP
   on 443, which is common now because of QUIC.
3. Plain TURN over TCP/443. For networks that block UDP entirely.
4. TURNS over TCP/443. Last resort, for networks where everything goes through
   an inspecting proxy.

Relaying costs quality, especially over TCP and all media of a relayed
participant flows through coTURN. Size the server for the number of relayed
participants you expect.

## One coTURN port, several public ports

coTURN listens on a single port inside the container, 3478 and serves:

- UDP: STUN and plain TURN
- TCP: plain TURN and TURNS, told apart from the first bytes of the connection

DTLS is off, so UDP is unambiguous. The Service maps the public ports onto that
one container port. So, the public port numbers are free to differ from it.

| Values                                             | Rendered Service      |
| -------------------------------------------------- | --------------------- |
| defaults                                           | `443/UDP`             |
| `turn.transport: "udp,tcp"`                        | `443/UDP`, `443/TCP`  |
| `turn.transport: "tcp"`                            | `443/TCP`             |
| `turns.enabled: true`                              | `443/UDP`, `443/TCP`  |
| `turns.enabled: true`, `turn.transport: "udp,tcp"` | `443/UDP`, `443/TCP`  |
| `turns.enabled: true`, `service.ports.turns: 5349` | `443/UDP`, `5349/TCP` |

Where plain TURN over TCP and TURNS land on the same public port, they share one
Service entry. coTURN serves both on it.

## Prerequisites

### A LoadBalancer that can carry TCP and UDP in one Service

Any configuration above with both a `/UDP` and a `/TCP` entry needs this. That
includes the common case of plain TURN over UDP together with TURNS, because
TURNS is always TCP.

Kubernetes allows it since v1.24. The LoadBalancer implementation has the final
say:

| Implementation                | Mixed TCP and UDP in one Service                   |
| ----------------------------- | -------------------------------------------------- |
| MetalLB                       | works                                              |
| AWS Load Balancer Controller  | v2.13.0 and later, see below                       |
| GKE                           | from 1.36.2-gke.1498000, needs `loadBalancerClass` |
| older in-tree cloud providers | not supported                                      |

On AWS, add the listener annotation to `coturn.service.annotations`:

```yaml
service.beta.kubernetes.io/aws-load-balancer-enable-tcp-udp-listener: "true"
```

If yours cannot do it, pick a single protocol: `turn.transport: "tcp"` with
TURNS or `turn.transport: "udp"` with TURNS disabled.

The symptom of an unsupported LoadBalancer is a Service stuck in `<pending>` or
one where only one of the two protocols is programmed.

### For TURNS

- cert-manager installed in the cluster
- a working `ClusterIssuer` or `Issuer`
- Kubernetes v1.28+ if using `acmeProxy`
- `turnHost` set, and DNS pointing at the exposed coTURN Service IP
- Reloader, so coTURN restarts when the certificate is renewed

## Configuration

Plain TURN over UDP/443, which is the default:

```yaml
turnHost: "turn.example.com"

coturn:
  enabled: true
```

Add plain TURN over TCP/443, so clients on UDP-blocking networks still get a
relay. Needs a mixed protocol LoadBalancer:

```yaml
turnHost: "turn.example.com"

coturn:
  enabled: true
  turn:
    transport: "udp,tcp"
```

Add TURNS on the same port:

```yaml
turnHost: "turn.example.com"

coturn:
  enabled: true
  replicaCount: 3

  turn:
    transport: "udp,tcp"

  turns:
    enabled: true
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

The ACME proxy is a small sidecar that forwards challenge requests to the
defined ingress, in this case Traefik, so the certificate can be validated. The
Service also publishes TCP/80 for it.

## TLS certificates

TLS certificates for client communication can be provided by setting
`coturn.turns.certificate.existingSecretName`, which should be a secret
containing keys `tls.crt` and `tls.key`. Alternatively, certificates can be
auto-created if `cert-manager` and a working `ClusterIssuer` or `Issuer` is
available. In the latter case, enabling `coturn.turns.acmeProxy` is required, as
ACME will be handled by whatever ingress is associated with your `Issuer` or
`ClusterIssuer`, but the external certificate authority will be sending ACME
validation requests to the IP associated with the domain set in `turnHost`, and
these requests have to be proxied back to the targeted ingress.

**Important:** coTURN does not reload its TLS certificate at runtime. When using
`coturn.turns.certificate.create` (cert-manager), if you do not run Reloader -
or otherwise restart the coTURN pods when the secret changes - coTURN keeps
serving the old certificate after cert-manager renews it. Everything appears to
work until the original certificate expires (for example, around 90 days with
Let's Encrypt), at which point TURNS breaks with no earlier warning. This chart
already sets the `secret.reloader.stakater.com/reload` annotation on the coTURN
Deployment, so installing Reloader once at the cluster level is enough;
otherwise, arrange for the pods to restart on renewal.

## Client side proxies

TURNS can pass through an outbound proxy on the client side, which is what makes
level 4 worth having. Chrome, Edge and current Firefox send TURN over TLS
through the proxy in an HTTP CONNECT tunnel. Safari is not reliable and the
Jitsi mobile apps ignore the system proxy. So, those users still need a direct
connection to 443.

Two things must be true on the proxy:

- it allows CONNECT to your TURN host on 443
- it does not do SSL inspection for that host

If the proxy opens the TLS, TURNS breaks and there is no workaround on the
client side. The proxy expects HTTP inside the TLS and TURN is not HTTP. Ask for
your TURN host to be excluded from SSL inspection.

Check it from inside the restricted network:

```
openssl s_client -proxy proxy.company.com:8080 -connect turn.example.com:443
```

If the certificate that comes back is the company CA rather than yours, the
proxy is inspecting.

## Allowed peers

To ensure that coTURN is able to relay traffic to your JVB's, you should ensure
that the ClusterIP ranges your JVB's (the "peer") is running on is covered by
the range(s) defined in `coturn.allowedPeerIPs`. It is empty by default, and the
chart denies the private ranges, so relaying to a JVB that is not publicly
reachable fails until you list its range:

```yaml
coturn:
  allowedPeerIPs:
    - "10.244.0.0-10.244.255.255"
```

## Relay port ranges

Relays provided by coTURN open a range of ports (internally). Each client
connected via TURNS is allocated to at least one UDP port - meaning the
theoretical maximum number of concurrent TURNS clients follows the formula:
`replica count * ports in range`. The default should be more than enough - but
this is a knob to turn in very demanding, high-traffic installations serving
many restricted clients. In all practicality, you are likely to hit bandwidth or
resource limits before having to extend this range, even with a single replica.

## Verifying

Check the Service carries the protocols you expect:

```
kubectl get svc -l app.kubernetes.io/component=coturn
```

Check what coTURN actually bound, and that nothing failed:

```
kubectl logs deploy/<release>-jitsi-meet-coturn
```

Check STUN answers:

```
turnutils_stunclient -p 443 turn.example.com
```

Then open the [Trickle ICE page][trickle-ice], enter your TURN server with a
valid credential and confirm you get a candidate of type `relay`. Do it once per
URL, so you know exactly what a given network allows:

- `turn:turn.example.com:443?transport=udp`
- `turn:turn.example.com:443?transport=tcp`
- `turns:turn.example.com:443?transport=tcp`

[trickle-ice]: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
