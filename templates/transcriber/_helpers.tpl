{{- define "jitsi-meet.transcriber.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-transcriber
{{- end -}}

{{- define "jitsi-meet.transcriber.secret" -}}
{{ include "jitsi-meet.transcriber.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.transcriber.secretName" -}}
{{- if .Values.transcriber.xmpp.existingSecretName -}}
{{    .Values.transcriber.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.transcriber.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.transcriber.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: transcriber
{{- end -}}

{{- define "jitsi-meet.transcriber.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: transcriber
{{- end -}}
