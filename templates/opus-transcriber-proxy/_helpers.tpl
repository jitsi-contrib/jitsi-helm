{{- define "jitsi-meet.opus-transcriber-proxy.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-opus-transcriber-proxy
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "opus-transcriber-proxy"
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "opus-transcriber-proxy"
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.secret" -}}
{{ include "jitsi-meet.opus-transcriber-proxy.fullname" . }}-secret
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.secretName" -}}
{{- if .Values.opusTranscriberProxy.existingSecretName -}}
{{    .Values.opusTranscriberProxy.existingSecretName }}
{{- else -}}
{{    include "jitsi-meet.opus-transcriber-proxy.secret" . }}
{{- end -}}
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.configmap" -}}
{{ include "jitsi-meet.opus-transcriber-proxy.fullname" . }}
{{- end -}}

{{- define "jitsi-meet.opus-transcriber-proxy.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.opus-transcriber-proxy.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.opus-transcriber-proxy.fullname" . }}.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}

{{/*
Websocket URL that Jicofo hands to JVB. {{MEETING_ID}} is Jicofo's OWN
placeholder (resolved by Jicofo itself at runtime), not Helm syntax - it must
be emitted literally. Never pipe this helper's output through `tpl`.
*/}}
{{- define "jitsi-meet.opus-transcriber-proxy.urlTemplate" -}}
{{- printf "ws://%s:%v/transcribe?sessionId={{MEETING_ID}}&sendBack=true" (include "jitsi-meet.opus-transcriber-proxy.server" .) .Values.opusTranscriberProxy.service.port -}}
{{- end -}}
