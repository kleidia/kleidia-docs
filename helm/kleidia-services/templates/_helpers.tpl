{{/*
Expand the name of the chart.
*/}}
{{- define "kleidia-services.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kleidia-services.fullname" -}}
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
{{- define "kleidia-services.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Construct image reference with optional global registry prefix
Usage: {{ include "kleidia-services.image" (dict "repository" "postgres" "tag" "15" "context" $) }}
*/}}
{{- define "kleidia-services.image" -}}
{{- $registry := .context.Values.global.registry.host -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{/*
Construct third-party image reference with optional global registry prefix
Usage: {{ include "kleidia-services.thirdPartyImage" (dict "image" .Values.thirdPartyImages.postgres "context" $) }}
For images like "dhi.io/postgres:16", preserves the full reference
When global.registry.host is set, strips original registry and prefixes with global registry
*/}}
{{- define "kleidia-services.thirdPartyImage" -}}
{{- $registry := .context.Values.global.registry.host -}}
{{- $image := .image -}}
{{- if $registry -}}
  {{- /* Extract image name and tag from full reference (e.g., "dhi.io/postgres:16" -> "postgres:16") */ -}}
  {{- $parts := splitList "/" $image -}}
  {{- $lastPart := index $parts (sub (len $parts) 1) -}}
  {{- printf "%s/%s" $registry $lastPart -}}
{{- else -}}
  {{- $image -}}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kleidia-services.labels" -}}
helm.sh/chart: {{ include "kleidia-services.chart" . }}
{{ include "kleidia-services.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kleidia-services.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kleidia-services.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

