{{- define "jitsi-meet.coturn.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-coturn
{{- end -}}

{{- define "jitsi-meet.coturn.secret" -}}
{{ include "jitsi-meet.coturn.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.coturn.secretName" -}}
{{- if .Values.coturn.staticAuth.existingSecretName -}}
{{    .Values.coturn.staticAuth.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.coturn.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.coturn.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: coturn
{{- end -}}

{{- define "jitsi-meet.coturn.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: coturn
{{- end -}}
