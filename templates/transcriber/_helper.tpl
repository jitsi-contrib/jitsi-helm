
{{- define "jitsi-meet.transcriber.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-transcriber
{{- end -}}

{{- define "jitsi-meet.transcriber.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: transcriber
{{- end -}}

{{- define "jitsi-meet.transcriber.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: transcriber
{{- end -}}

{{- define "jitsi-meet.transcriber.secret" -}}
{{ include "call-nested" (list . "prosody" "prosody.fullname") }}-transcriber
{{- end -}}
