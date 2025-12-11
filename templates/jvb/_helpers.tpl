{{- define "jitsi-meet.jvb.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jvb
{{- end -}}

{{- define "jitsi-meet.jvb.secret" -}}
{{ include "jitsi-meet.jvb.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.jvb.secretName" -}}
{{- if .Values.jvb.xmpp.existingSecretName -}}
{{    .Values.jvb.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.jvb.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jvb.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "jvb"
{{- end -}}

{{- define "jitsi-meet.jvb.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "jvb"
{{- end -}}
