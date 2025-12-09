{{/* Expand the name of the chart. */}}
{{- define "jitsi-meet.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
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

{{/* Create chart name and version as used by the chart label.  */}}
{{- define "jitsi-meet.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common name */}}
{{- define "jitsi-meet.common" -}}
{{- printf "%s-common" (include "jitsi-meet.fullname" .) -}}
{{- end -}}

{{/* Common labels */}}
{{- define "jitsi-meet.labels" -}}
helm.sh/chart: {{ include "jitsi-meet.chart" . }}
{{ include "jitsi-meet.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Selector labels */}}
{{- define "jitsi-meet.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jitsi-meet.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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

{{- define "jitsi-meet.publicURL" -}}
{{- if .Values.publicURL -}}
{{-   .Values.publicURL -}}
{{- else -}}
{{-   $host := "" -}}
{{-   $tlsEnabled := false -}}
{{-   if and .Values.web.ingress.enabled .Values.web.ingress.tls -}}
{{-     $host = (.Values.web.ingress.tls|first).hosts|first -}}
{{-     $tlsEnabled = true -}}
{{-   else if and .Values.web.ingress.enabled .Values.web.ingress.hosts -}}
{{-     $host = (.Values.web.ingress.hosts|first).host -}}
{{-   end -}}
{{-   if $host -}}
{{-     if $tlsEnabled -}}https://{{- else -}}http://{{- end -}}
{{-     $host -}}
{{-   else -}}
{{ required "A publicURL must be set if Ingress is not enabled or does not define a host." .Values.publicURL }}
{{-   end -}}
{{- end -}}
{{- end -}}
