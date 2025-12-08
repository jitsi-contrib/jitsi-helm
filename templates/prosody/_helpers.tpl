{{- define "jitsi-meet.prosody.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-prosody
{{- end -}}

{{- define "jitsi-meet.prosody.secret" -}}
{{ include "jitsi-meet.prosody.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.prosody.secretName" -}}
{{- if .Values.prosody.jwt.existingSecretName -}}
{{    .Values.prosody.jwt.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.prosody.secret" . }}
{{- end -}}
{{- end -}}
 
{{- define "jitsi-meet.prosody.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: prosody
{{- end -}}
 
{{- define "jitsi-meet.prosody.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: prosody
{{- end -}}
