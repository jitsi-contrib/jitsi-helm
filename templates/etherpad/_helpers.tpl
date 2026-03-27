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
