{{/*
Expand the name of the chart.
*/}}
{{- define "kleidia-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kleidia-platform.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kleidia-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Construct image reference with optional global registry prefix
Usage: {{ include "kleidia-platform.image" (dict "repository" "alpine" "tag" "latest" "context" $) }}
*/}}
{{- define "kleidia-platform.image" -}}
{{- $registry := .context.Values.global.registry.host -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kleidia-platform.labels" -}}
helm.sh/chart: {{ include "kleidia-platform.chart" . }}
{{ include "kleidia-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kleidia-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kleidia-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

