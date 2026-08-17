{{- define "jitsi-meet.etherpad.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-etherpad
{{- end -}}

{{- define "jitsi-meet.etherpad.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "etherpad"
{{- end -}}

{{- define "jitsi-meet.etherpad.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "etherpad"
{{- end -}}

{{- define "jitsi-meet.etherpad.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.etherpad.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.etherpad.fullname" . }}.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}
