# Sizing: capacity, resources, HA, and quality

This guide answers "for N users, what should I set?" It ties together three
things that trade off against each other: **quality** (resolution/bitrate),
**resource cost** (CPU/RAM per pod), and **availability** (how much a single
failure can take down). There is no single number that answers "how many
users" independent of the other two -- this doc gives you the model and the
knobs, plus concrete starting points to load-test from.

## The one fact that determines everything else

**JVB does not transcode.** It receives SRTP, decrypts, and re-encrypts/
forwards to other participants. It never re-encodes video. That means its
cost is driven by **bytes and packets moved**, not by resolution rendering --
and the number of bytes/packets moved is:

```
cost ≈ participants × (streams each participant receives)
```

`streams each participant receives` is capped by
`jicofo.extraEnvs.JICOFO_CONF_MAX_VIDEO_SENDERS` (see
[the quality guide's env var reference](/docs/guides/exposing.md) and the
[values-sample.yaml](/values-sample.yaml) / [values-sample-1080p.yaml](/values-sample-1080p.yaml)
files for where this is set). **Without that cap, cost grows roughly with the
square of room size** (everyone forwards to everyone), which is why a single
uncapped 720p meeting can overwhelm a bridge at a headcount far below what
the same bridge handles fine with the cap in place.

This is also why "how many users can a JVB handle" has no single answer:
100 users with `MAX_VIDEO_SENDERS=3` (everyone effectively sees a 3-tile
speaker view) costs a fraction of what 30 users with no cap (everyone sees
everyone in full gallery view) costs.

## Grounding the numbers

Two real, published data points anchor the estimates below (I looked these up
rather than guessing):

- Jitsi's own DevOps guide: *"4 or 8 CPU with 8GB RAM seems to be a good
  [videobridge] configuration."*
- A widely-cited AWS load test: a `c5.xlarge` (4 vCPU/8GB) videobridge
  sustained on the order of **1000 forwarded streams at ~550Mbps aggregate**
  -- but that was spread across many separate, smaller conferences, not one
  giant room. One room concentrates load on one bridge process at once, so a
  single-conference ceiling is much lower than that aggregate number.
- Jicofo's own defaults assume ~80-100 participants in a single conference
  before it wants to spread the room across bridges via Octo
  (`max-bridge-participants` default 80, `average-participant-stress`
  default implies ~100). Those defaults are tuned for a "capable" bridge in
  the 4-8 vCPU range, not a 2 vCPU one.

Everything below extrapolates from those anchors using the cost model above.
**Treat every number in this doc as a starting point to load-test from, not a
guarantee** -- real capacity also depends on your network, whether cameras
are on, screen-share (an extra high-bitrate stream on top), and codec
(VP8/VP9/AV1 all cost differently).

## Capacity table: one conference, one JVB, with `MAX_VIDEO_SENDERS` capped

| JVB resources | 720p ceiling (senders capped ~5) | 1080p ceiling (senders capped ~3) |
|---|---|---|
| 1 vCPU / 1Gi | ~10-15 | not recommended |
| 2 vCPU / 2Gi ([values-sample.yaml](/values-sample.yaml)) | ~25-35 | ~10-15 |
| 4 vCPU / 4Gi ([values-sample-1080p.yaml](/values-sample-1080p.yaml)) | ~60-80 | ~30-40 |
| 8 vCPU / 8Gi | ~120-150 | ~70-90 |

Without a sender cap (`MAX_VIDEO_SENDERS` unset / very high), cut every
number above roughly in half to a third -- the O(n²) effect starts to bite
well before these ceilings.

**Beyond a single conference's ceiling, don't make one JVB pod bigger --
add more JVB pods and let Octo spread the room across them** (this chart's
`portsPerIP`/`publicIPs` matrix, `octo.enabled: true`). Octo scales
near-linearly with pod count for this reason: each additional bridge adds
its own forwarding capacity, and relay traffic between bridges is
comparatively cheap.

## Availability ceiling of this chart (read this before promising "high HA")

Horizontally scalable, verified in the templates:
- **JVB** -- any number of instances via the `publicIPs`/`portsPerIP` matrix
  (see [exposing.md](/docs/guides/exposing.md)). A pod dying only drops the
  participants on that one bridge; Octo/Jicofo reassign them.
- **Jibri** -- `jibri.replicaCount`, N concurrent recording/streaming slots.
- **Web** -- `web.replicaCount`, stateless nginx, trivially horizontal.

**Not horizontally scalable in this chart -- confirmed in the templates,
hardcoded regardless of values:**
- **Jicofo** -- `templates/jicofo/deployment.yaml` hardcodes `replicas: 1`.
  Jicofo is the conference "focus": it owns bridge selection and
  session signaling for every active conference. If its pod dies, Kubernetes
  reschedules it, but **every active conference loses its focus during the
  restart** -- a real, if brief, full-outage window. There is no
  `jicofo.replicaCount` in this chart's values.
- **Prosody** -- `templates/prosody/statefulset.yaml` hardcodes
  `replicas: 1`. Same story for XMPP signaling/MUC membership.

**Implication:** with this chart, "high HA" tops out at *"a JVB pod failure
is invisible to everyone except its own participants, who get silently
reassigned"* -- it does **not** mean "no single point of failure at all."
Jicofo and Prosody remain SPOFs; a `PodDisruptionBudget` and prompt
rescheduling reduce *downtime* but don't eliminate the outage window. If you
need Jicofo/Prosody HA, that requires changes this chart doesn't currently
make (Jicofo's `jicofo-selector` multi-instance mode, Prosody clustering) --
out of scope here, flagging it rather than pretending otherwise.

## Decision table: for N concurrent users in one room, what to set

Assumes the shared-IP-matrix LoadBalancer topology from
[values-sample.yaml](/values-sample.yaml), Octo enabled, `disableStun: true`.
"JVBs" = pod count; give each its own entry in `publicIPs`/`portsPerIP`.

| N users (1 room) | Quality | JVBs × resources | `MAX_VIDEO_SENDERS` | `MAX_BRIDGE_PARTICIPANTS` | Web/Jibri |
|---|---|---|---|---|---|
| ≤ 25 | 720p | 1 × (2 vCPU/2Gi) | 5 | 30 | web ×1 |
| ≤ 60 | 720p | 1 × (4 vCPU/4Gi) | 5 | 60 | web ×2 |
| ≤ 150 | 720p | 2-3 × (4 vCPU/4Gi), Octo spreads the room | 5 | 60 (per bridge) | web ×2, `PodDisruptionBudget` on web |
| ≤ 400 | 720p | 6-8 × (4 vCPU/4Gi) | 4-5 | 50-60 | web ×3+, Jibri sized separately per concurrent recording |
| ≤ 15 | 1080p | 1 × (2 vCPU/2Gi) | 3 | 15 | web ×1 |
| ≤ 40 | 1080p | 1 × (4 vCPU/4Gi) | 3 | 40 | web ×2 |
| ≤ 120 | 1080p | 3-4 × (4 vCPU/4Gi), Octo spreads the room | 3 | 40 (per bridge) | web ×2-3 |

Reading this as "least resource for N users": pick the smallest row that
covers your target N, then load-test at ~120% of that N before calling it
production-ready -- the table extrapolates from published anchors, it isn't
a benchmark of your specific cluster/network.

**Recording (Jibri) is sized independently of room size** -- one Jibri pod
handles exactly one concurrent recording regardless of whether the room has
10 or 400 people, because it's rendering the composed meeting view once, not
per-participant. Size `jibri.replicaCount` to how many *simultaneous*
recordings/streams you expect, not to N.

## Applying this

1. Start from [values-sample.yaml](/values-sample.yaml) (720p) or
   [values-sample-1080p.yaml](/values-sample-1080p.yaml) (1080p).
2. Pick your row from the decision table above; set `jvb.resources`,
   `jvb.publicIPs`/`portsPerIP` (pod count), and the `jicofo.extraEnvs`
   trio (`JICOFO_CONF_MAX_VIDEO_SENDERS`, `MAX_BRIDGE_PARTICIPANTS`,
   `BRIDGE_STRESS_THRESHOLD`) accordingly.
3. Load-test with multiple browser tabs/`jitsi-meet-torture` at your target
   N before going live; watch `/colibri/stats` or the Grafana dashboard
   (`jvb.metrics.grafanaDashboards.enabled`) for CPU and packet-loss signals
   under load.
4. If you need Jicofo/Prosody to survive a pod failure without a signaling
   outage, that's a gap in this chart today -- treat it as a known
   limitation, not something any values change here can close.
