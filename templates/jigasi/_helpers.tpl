{{- define "jitsi-meet.jigasi.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jigasi
{{- end -}}

{{- define "jitsi-meet.jigasi.secret" -}}
{{ include "jitsi-meet.jigasi.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.jigasi.secretName" -}}
{{- if .Values.jigasi.xmpp.existingSecretName -}}
{{    .Values.jigasi.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.jigasi.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jigasi.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: jigasi
{{- end -}}

{{- define "jitsi-meet.jigasi.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: jigasi
{{- end -}}
