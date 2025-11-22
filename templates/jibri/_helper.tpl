
{{- define "jitsi-meet.jibri.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jibri
{{- end -}}

{{- define "jitsi-meet.jibri.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: jibri
{{- end -}}

{{- define "jitsi-meet.jibri.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: jibri
{{- end -}}

{{- define "jitsi-meet.jibri.secret" -}}
{{- default (printf "%s-jibri" (include "call-nested" (list . "prosody" "prosody.fullname"))) .Values.jibri.existingSecret -}}
{{- end -}}
