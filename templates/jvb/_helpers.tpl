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
{{- end -}}
