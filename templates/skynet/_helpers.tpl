{{- define "jitsi-meet.skynet.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-skynet
{{- end -}}

{{- define "jitsi-meet.skynet.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "skynet"
{{- end -}}

{{- define "jitsi-meet.skynet.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "skynet"
{{- end -}}

{{- define "jitsi-meet.skynet.server" -}}
{{- if .Values.global.clusterDomain -}}
{{    include "jitsi-meet.fullname" . }}-skynet.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}
{{- else -}}
{{    include "jitsi-meet.fullname" . }}-skynet.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}

{{/*
Websocket base URL the Transcriber (jigasi) uses to reach Skynet's
streaming-whisper endpoint. jigasi appends the connection id itself, so this
must NOT include a trailing id or query string.
Returns the external URL when useExternalSkynet is set, otherwise the
in-cluster Service URL.
*/}}
{{- define "jitsi-meet.skynet.whisperURL" -}}
{{- if .Values.skynet.useExternalSkynet -}}
{{-   required "skynet.url must be set when skynet.useExternalSkynet is true" .Values.skynet.url -}}
{{- else -}}
{{-   printf "ws://%s:%v/streaming-whisper/ws" (include "jitsi-meet.skynet.server" .) .Values.skynet.service.port -}}
{{- end -}}
{{- end -}}
