{{- define "news_app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "news_app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "news_app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "news_app.labels" -}}
helm.sh/chart: {{ include "news_app.chart" . }}
{{ include "news_app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "news_app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "news_app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "news_app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "news_app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "news_app.namespace" -}}
{{- if .Values.namespace }}
{{- .Values.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{- define "news_app.activeServiceName" -}}
{{- printf "%s-%s" (include "news_app.fullname" .) (default "active" .Values.service.activeSuffix) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "news_app.previewServiceName" -}}
{{- printf "%s-%s" (include "news_app.fullname" .) (default "preview" .Values.service.previewSuffix) | trunc 63 | trimSuffix "-" }}
{{- end }}
