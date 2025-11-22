
{{- define "jitsi-meet.jicofo.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jicofo
{{- end -}}

{{- define "jitsi-meet.jicofo.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: jicofo
{{- end -}}

{{- define "jitsi-meet.jicofo.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: jicofo
{{- end -}}

{{- define "jitsi-meet.jicofo.secret" -}}
{{- default (printf "%s-jicofo" (include "call-nested" (list . "prosody" "prosody.fullname"))) .Values.jicofo.existingSecret -}}
{{- end -}}
