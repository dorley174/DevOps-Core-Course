{{/*
Compatibility wrappers around the shared common-lib helper templates.
*/}}
{{- define "devops-info-service.name" -}}
{{ include "common-lib.name" . }}
{{- end -}}

{{- define "devops-info-service.fullname" -}}
{{ include "common-lib.fullname" . }}
{{- end -}}

{{- define "devops-info-service.chart" -}}
{{ include "common-lib.chart" . }}
{{- end -}}

{{- define "devops-info-service.labels" -}}
{{ include "common-lib.labels" . }}
{{- end -}}

{{- define "devops-info-service.selectorLabels" -}}
{{ include "common-lib.selectorLabels" . }}
{{- end -}}

{{- define "devops-info-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "devops-info-service.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "devops-info-service.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else if .Values.secrets.name -}}
{{- .Values.secrets.name -}}
{{- else -}}
{{- printf "%s-secret" (include "devops-info-service.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "devops-info-service.hookImage" -}}
{{- printf "%s:%s" .Values.hooks.image.repository .Values.hooks.image.tag -}}
{{- end -}}
