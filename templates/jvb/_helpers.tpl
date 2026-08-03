{{- define "jitsi-meet.jvb.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jvb
{{- end -}}

{{- define "jitsi-meet.jvb.secret" -}}
{{ include "jitsi-meet.jvb.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.jvb.secretName" -}}
{{- if .Values.jvb.xmpp.existingSecretName -}}
{{    .Values.jvb.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.jvb.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jvb.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "jvb"
{{- end -}}

{{- define "jitsi-meet.jvb.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "jvb"
{{- end -}}

{{/*
Per-instance resource name: <fullname>-jvb-<index>
Call as: include "jitsi-meet.jvb.instanceFullname" (dict "ctx" $ "index" $i)
*/}}
{{- define "jitsi-meet.jvb.instanceFullname" -}}
{{ printf "%s-%v" (include "jitsi-meet.jvb.fullname" .ctx) .index | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Normalized JVB instance list -- the single source of truth for how many JVB
instances exist and which public IP / UDP port each one owns.

Consume with:
  {{- $instances := fromYamlArray (include "jitsi-meet.jvb.instanceList" .) }}

Each element is a dict with keys: index, publicIP, port, nodePort,
sharingKey, firstOnIP.

When jvb.publicIPs and jvb.portsPerIP are both set, this declares an
IP x port matrix: len(publicIPs) * portsPerIP instances, indexed so that
instance i sits on publicIPs[i/portsPerIP] at port UDPPort+(i%portsPerIP).

Otherwise it falls back to the legacy behavior: one instance, or (when
useHostPort is enabled) portRangeSize instances, none carrying a per-instance
publicIP -- callers must fall back to the joined jvb.publicIPs list.
*/}}
{{- define "jitsi-meet.jvb.instanceList" -}}
{{- $v := .Values.jvb -}}
{{- $out := list -}}
{{- if and $v.publicIPs $v.portsPerIP -}}
{{-   $per := int $v.portsPerIP -}}
{{-   range $i := until (int (mul (len $v.publicIPs) $per)) -}}
{{-     $ip := index $v.publicIPs (div $i $per) -}}
{{-     $out = append $out (dict
          "index" $i
          "publicIP" $ip
          "port" (add (int $v.UDPPort) (mod $i $per))
          "nodePort" (ternary $v.nodePort nil (eq $per 1))
          "sharingKey" $ip
        ) -}}
{{-   end -}}
{{- else -}}
{{/*  Legacy path: identical instance count and ports as before this change. */}}
{{-   $count := 1 -}}
{{-   if $v.useHostPort }}{{ $count = int ($v.portRangeSize | default 1) }}{{ end -}}
{{-   range $i := until $count -}}
{{-     $out = append $out (dict
          "index" $i
          "publicIP" ""
          "port" (add (int $v.UDPPort) $i)
          "nodePort" $v.nodePort
          "sharingKey" ""
        ) -}}
{{-   end -}}
{{- end -}}
{{/* mark the first Service on each public IP, for extraPorts placement */}}
{{- $seen := dict -}}
{{- $final := list -}}
{{- range $inst := $out -}}
{{-   $k := $inst.publicIP | default "_" -}}
{{-   $_ := set $inst "firstOnIP" (not (hasKey $seen $k)) -}}
{{-   $_ := set $seen $k true -}}
{{-   $final = append $final $inst -}}
{{- end -}}
{{- toYaml $final -}}
{{- end -}}

{{/*
Guard rails for the JVB instance matrix / per-instance Services. Call once
with `{{- include "jitsi-meet.jvb.validate" . }}` -- it renders nothing on
success and aborts the whole render via `fail` otherwise.
*/}}
{{- define "jitsi-meet.jvb.validate" -}}
{{- $v := .Values.jvb -}}
{{- $instances := fromYamlArray (include "jitsi-meet.jvb.instanceList" .) -}}

{{- if and $v.portsPerIP (gt (int ($v.portRangeSize | default 1)) 1) -}}
{{-   fail "jvb: jvb.portsPerIP replaces jvb.portRangeSize; do not set both" -}}
{{- end -}}
{{- if and $v.portsPerIP (not $v.publicIPs) -}}
{{-   fail "jvb: jvb.portsPerIP requires a non-empty jvb.publicIPs list" -}}
{{- end -}}
{{- if and $v.portsPerIP (lt (int $v.portsPerIP) 1) -}}
{{-   fail "jvb: jvb.portsPerIP must be >= 1" -}}
{{- end -}}

{{- if and $v.service.enabled $v.service.perInstanceServices -}}
{{-   if ne (int $v.replicaCount) 1 -}}
{{-     fail "jvb: jvb.replicaCount must be 1 when jvb.service.perInstanceServices is enabled (each Service targets exactly one pod; more replicas send UDP to a random bridge)" -}}
{{-   end -}}
{{-   if $v.useHostNetwork -}}
{{-     fail "jvb: jvb.service.perInstanceServices is incompatible with jvb.useHostNetwork" -}}
{{-   end -}}
{{-   if $v.useHostPort -}}
{{-     fail "jvb: jvb.service.perInstanceServices is incompatible with jvb.useHostPort" -}}
{{-   end -}}
{{-   if and (gt (len $instances) 1) (eq $v.service.type "LoadBalancer") -}}
{{-     if not $v.service.ipSharing.annotationKey -}}
{{-       fail "jvb: jvb.service.ipSharing.annotationKey must be set when several LoadBalancer Services share a public IP" -}}
{{-     end -}}
{{-     if eq $v.service.externalTrafficPolicy "Local" -}}
{{-       fail "jvb: shared LoadBalancer IPs require jvb.service.externalTrafficPolicy: Cluster (MetalLB rejects Local when Services select different pods)" -}}
{{-     end -}}
{{-   end -}}
{{-   if and $v.nodePort (gt (len $instances) 1) -}}
{{-     fail "jvb: jvb.nodePort cannot be shared by multiple per-instance Services; unset it to auto-allocate a nodePort per instance" -}}
{{-   end -}}
{{- end -}}

{{- if and $v.service.enabled (not $v.service.perInstanceServices) (gt (len $instances) 1) -}}
{{-   fail "jvb: more than one JVB instance behind a single shared Service routes UDP to a random bridge; set jvb.service.perInstanceServices=true, or disable jvb.service and use hostPort" -}}
{{- end -}}

{{- $seenIPPort := dict -}}
{{- range $inst := $instances -}}
{{-   $key := printf "%s/%v" ($inst.publicIP | default "_") $inst.port -}}
{{-   if hasKey $seenIPPort $key -}}
{{-     fail (printf "jvb: duplicate publicIP/port combination %s (instances %v and %v)" $key (index $seenIPPort $key) $inst.index) -}}
{{-   end -}}
{{-   $_ := set $seenIPPort $key $inst.index -}}
{{-   if or (lt (int $inst.port) 1024) (gt (int $inst.port) 65535) -}}
{{-     fail (printf "jvb: instance %v port %v out of range 1024-65535" $inst.index $inst.port) -}}
{{-   end -}}
{{- end -}}

{{- $g := $v.gracefulShutdown -}}
{{- if and $g.preStop.enabled (not $g.enabled) -}}
{{-   fail "jvb: jvb.gracefulShutdown.preStop.enabled requires jvb.gracefulShutdown.enabled (the hook needs SHUTDOWN_REST_ENABLED)" -}}
{{- end -}}
{{- if and $g.preStop.enabled (ge (int $g.preStop.maxWaitSeconds) (sub (int $g.terminationGracePeriodSeconds) 10)) -}}
{{-   fail "jvb: jvb.gracefulShutdown.preStop.maxWaitSeconds must be at least 10s below jvb.gracefulShutdown.terminationGracePeriodSeconds, or kubelet SIGKILLs mid-drain" -}}
{{- end -}}
{{- if and $g.preStop.enabled (lt (int $g.preStop.pollIntervalSeconds) 1) -}}
{{-   fail "jvb: jvb.gracefulShutdown.preStop.pollIntervalSeconds must be >= 1" -}}
{{- end -}}
{{- end -}}

{{/*
preStop drain script for JVB. Call with the ROOT context: $
  {{- include "jitsi-meet.jvb.preStopScript" $ | nindent 18 }}

POSIX sh, no jq (not guaranteed present in the jitsi/jvb image), tries curl
then wget. Always exits 0 -- a failed/timed-out hook should only produce log
noise; kubelet proceeds to SIGTERM either way (see the long comment on
jvb.gracefulShutdown in values.yaml for why this hook is defence-in-depth
only, not the primary drain mechanism, in the perInstanceServices topology).
*/}}
{{- define "jitsi-meet.jvb.preStopScript" -}}
{{- $g := .Values.jvb.gracefulShutdown -}}
{{- $wait := int $g.preStop.maxWaitSeconds -}}
{{- $poll := int $g.preStop.pollIntervalSeconds -}}
{{- $min  := int $g.preStop.minParticipants -}}
- /bin/sh
- -c
- |
  set -u
  B=http://localhost:8080
  if command -v curl >/dev/null 2>&1; then
    GET() { curl -sf -m 5 "$1"; }
    POST() { curl -sf -m 5 -H 'Content-Type: application/json' \
      -d '{"graceful-shutdown":"true"}' "$1"; }
  elif command -v wget >/dev/null 2>&1; then
    GET() { wget -q -O - -T 5 "$1"; }
    POST() { wget -q -O - -T 5 --header='Content-Type: application/json' \
      --post-data='{"graceful-shutdown":"true"}' "$1"; }
  else
    echo "prestop: neither curl nor wget in image; skipping drain" >&2
    exit 0
  fi
  num() { printf '%s' "$2" | tr ',{}' '\n\n\n' \
    | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    | head -1; }
  POST "$B/colibri/shutdown" >/dev/null 2>&1 \
    || { echo "prestop: shutdown POST failed (is SHUTDOWN_REST_ENABLED set?)" >&2; exit 0; }
  e=0
  while [ "$e" -lt {{ $wait }} ]; do
    s=$(GET "$B/colibri/stats" 2>/dev/null) || exit 0
    l=$(num local_endpoints "$s")
    if [ -z "$l" ]; then
      p=$(num participants "$s"); o=$(num octo_endpoints "$s")
      [ -n "$p" ] || p=0
      [ -n "$o" ] || o=0
      l=$((p - o))
    fi
    if [ "$l" -le {{ $min }} ]; then
      echo "prestop: drained ($l local participants)" >&2
      exit 0
    fi
    sleep {{ $poll }}
    e=$((e + {{ $poll }}))
  done
  echo "prestop: drain timed out after {{ $wait }}s with $l local participants remaining" >&2
  exit 0
{{- end -}}
