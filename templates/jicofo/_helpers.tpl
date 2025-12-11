{{- define "jitsi-meet.jicofo.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jicofo
{{- end -}}

{{- define "jitsi-meet.jicofo.secret" -}}
{{ include "jitsi-meet.jicofo.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.jicofo.secretName" -}}
{{- if .Values.jicofo.xmpp.existingSecretName -}}
{{    .Values.jicofo.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.jicofo.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jicofo.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "jicofo"
{{- end -}}

{{- define "jitsi-meet.jicofo.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "jicofo"
{{- end -}}
