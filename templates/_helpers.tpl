{{/* Expand the name of the chart. */}}
{{- define "jitsi-meet.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
If the release name contains chart name it will be used as a full name.
*/}}
{{- define "jitsi-meet.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{-   .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{-   $name := default .Chart.Name .Values.nameOverride -}}
{{-   if contains $name .Release.Name -}}
{{-     .Release.Name | trunc 63 | trimSuffix "-" -}}
{{-   else -}}
{{-     printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{-   end -}}
{{- end -}}
{{- end -}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "jitsi-meet.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common name */}}
{{- define "jitsi-meet.common" -}}
{{- printf "%s-common" (include "jitsi-meet.fullname" .) -}}
{{- end -}}

{{/* Common labels */}}
{{- define "jitsi-meet.labels" -}}
helm.sh/chart: {{ include "jitsi-meet.chart" . | quote }}
{{ include "jitsi-meet.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{/* Selector labels */}}
{{- define "jitsi-meet.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jitsi-meet.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/* Create the name of the service account to use */}}
{{- define "jitsi-meet.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{-   .Values.serviceAccount.name | default (include "jitsi-meet.fullname" .) -}}
{{- else -}}
{{-   .Values.serviceAccount.name | default "default" -}}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.xmpp.domain" -}}
{{- if .Values.xmpp.domain -}}
{{-   .Values.xmpp.domain -}}
{{- else -}}
{{-   if .Values.global.clusterDomain -}}
{{-     printf "%s.svc.%s" .Release.Namespace .Values.global.clusterDomain -}}
{{-   else -}}
{{-     printf "%s.svc" .Release.Namespace -}}
{{-   end -}}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.xmpp.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.fullname" . }}-prosody.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.fullname" . }}-prosody.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.excalidraw.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.fullname" . }}-excalidraw.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.fullname" . }}-excalidraw.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.etherpad.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.fullname" . }}-etherpad.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.fullname" . }}-etherpad.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.publicURL" -}}
{{- if .Values.publicURL -}}
{{-   .Values.publicURL -}}
{{- else -}}
{{-   $host := "" -}}
{{-   $tlsEnabled := false -}}
{{-   if .Values.web.gateway.enabled -}}
{{-     $host = .Values.web.gateway.host -}}
{{-     $tlsEnabled = .Values.web.gateway.tls.enabled -}}
{{-   else if .Values.web.ingress.enabled -}}
{{-     if .Values.web.ingress.tls -}}
{{-       $host = (index (index .Values.web.ingress.tls 0).hosts 0) -}}
{{-       $tlsEnabled = true -}}
{{-     else if .Values.web.ingress.hosts -}}
{{-       $host = (index .Values.web.ingress.hosts 0).host -}}
{{-     end -}}
{{-   end -}}

{{-   if $host -}}
{{-     if $tlsEnabled -}}
{{-       printf "https://%s" $host -}}
{{-     else -}}
{{-       printf "http://%s" $host -}}
{{-     end -}}
{{-   else -}}
{{      required "A publicURL must be set if neither Gateway nor Ingress is enabled or defines a host." .Values.publicURL }}
{{-   end -}}

{{- end -}}
{{- end -}}
