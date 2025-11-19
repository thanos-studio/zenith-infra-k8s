{{- define "zenith_app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "zenith_app.fullname" -}}
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

{{- define "zenith_app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "zenith_app.labels" -}}
helm.sh/chart: {{ include "zenith_app.chart" . }}
{{ include "zenith_app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "zenith_app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zenith_app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "zenith_app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zenith_app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "zenith_app.namespace" -}}
{{- if .Values.namespace | trim }}
{{- .Values.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{- define "zenith_app.activeServiceName" -}}
{{- printf "%s-%s" (include "zenith_app.fullname" .) (default "active" .Values.service.activeSuffix) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "zenith_app.previewServiceName" -}}
{{- printf "%s-%s" (include "zenith_app.fullname" .) (default "preview" .Values.service.previewSuffix) | trunc 63 | trimSuffix "-" }}
{{- end }}
