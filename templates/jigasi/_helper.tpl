
{{- define "jitsi-meet.jigasi.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jigasi
{{- end -}}

{{- define "jitsi-meet.jigasi.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: jigasi
{{- end -}}

{{- define "jitsi-meet.jigasi.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: jigasi
{{- end -}}

{{- define "jitsi-meet.jigasi.secret" -}}
{{- default (printf "%s-jigasi" (include "call-nested" (list . "prosody" "prosody.fullname"))) .Values.jigasi.existingSecret -}}
{{- end -}}
