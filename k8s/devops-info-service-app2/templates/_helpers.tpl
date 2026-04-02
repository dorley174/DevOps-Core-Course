{{/*
Compatibility wrappers around the shared common-lib helper templates.
*/}}
{{- define "devops-info-service-app2.name" -}}
{{ include "common-lib.name" . }}
{{- end -}}

{{- define "devops-info-service-app2.fullname" -}}
{{ include "common-lib.fullname" . }}
{{- end -}}

{{- define "devops-info-service-app2.chart" -}}
{{ include "common-lib.chart" . }}
{{- end -}}

{{- define "devops-info-service-app2.labels" -}}
{{ include "common-lib.labels" . }}
{{- end -}}

{{- define "devops-info-service-app2.selectorLabels" -}}
{{ include "common-lib.selectorLabels" . }}
{{- end -}}

{{- define "devops-info-service-app2.hookImage" -}}
{{- printf "%s:%s" .Values.hooks.image.repository .Values.hooks.image.tag -}}
{{- end -}}
