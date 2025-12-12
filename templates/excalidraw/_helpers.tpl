{{- define "jitsi-meet.excalidraw.fullname" -}}
{{ include "jitsi-meet.fullname" . }}-excalidraw
{{- end -}}

{{- define "jitsi-meet.excalidraw.labels" -}}
{{ include "jitsi-meet.labels" . }}
app.kubernetes.io/component: "excalidraw"
{{- end -}}

{{- define "jitsi-meet.excalidraw.selectorLabels" -}}
{{ include "jitsi-meet.selectorLabels" . }}
app.kubernetes.io/component: "excalidraw"
{{- end -}}
