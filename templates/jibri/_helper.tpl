{{- define "jitsi-meet.jibri.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-jibri
{{- end -}}

{{- define "jitsi-meet.jibri.secret" -}}
{{ include "jitsi-meet.jibri.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.jibri.secretName" -}}
{{- if .Values.jibri.xmpp.existingSecretName -}}
{{    .Values.jibri.xmpp.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.jibri.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jibri.recorderSecret" -}}
{{ include "jitsi-meet.jibri.fullname" . }}-secret-recorder
{{- end -}}

{{- define "jitsi-meet.jibri.recorderSecretName" -}}
{{- if .Values.jibri.recorder.existingSecretName -}}
{{   .Values.jibri.recorder.existingSecretName }}
{{- else -}}
{{   include "jitsi-meet.jibri.recorderSecret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.jibri.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: jibri
{{- end -}}

{{- define "jitsi-meet.jibri.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: jibri
{{- end -}}
