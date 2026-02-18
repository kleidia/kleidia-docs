{{/*
Expand the name of the chart.
*/}}
{{- define "kleidia-data.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kleidia-data.fullname" -}}
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
{{- define "kleidia-data.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Construct image reference with optional global registry prefix
Usage: {{ include "kleidia-data.image" (dict "repository" "postgres" "tag" "15-alpine" "context" $) }}
*/}}
{{- define "kleidia-data.image" -}}
{{- $registry := .context.Values.global.registry.host -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{/*
Construct third-party image reference with optional global registry prefix
Usage: {{ include "kleidia-data.thirdPartyImage" (dict "image" .Values.thirdPartyImages.postgres "context" $) }}
For images like "postgres:18-alpine", preserves the full reference
When global.registry.host is set, strips original registry and prefixes with global registry
*/}}
{{- define "kleidia-data.thirdPartyImage" -}}
{{- $registry := .context.Values.global.registry.host -}}
{{- $image := .image -}}
{{- if $registry -}}
  {{- /* Extract image name and tag from full reference (e.g., "library/postgres:18" -> "postgres:18") */ -}}
  {{- $parts := splitList "/" $image -}}
  {{- $lastPart := index $parts (sub (len $parts) 1) -}}
  {{- printf "%s/%s" $registry $lastPart -}}
{{- else -}}
  {{- $image -}}
{{- end -}}
{{- end }}

{{/*
Determine if CNPG should be used based on Kubernetes version
CNPG operator v1.28.0 requires Kubernetes 1.32+
See: https://github.com/cloudnative-pg/cloudnative-pg/releases/tag/v1.28.0
Supported: K8s 1.32, 1.33, 1.34 | PostgreSQL 14, 15, 16, 17, 18
Returns "true" if K8s >= 1.32, "false" otherwise
*/}}
{{- define "kleidia-data.cnpgSupported" -}}
{{- $k8sVersion := .Capabilities.KubeVersion.Minor -}}
{{- /* Remove any suffix like "+" from version string */ -}}
{{- $minorVersion := regexReplaceAll "[^0-9]" $k8sVersion "" -}}
{{- $minorInt := int $minorVersion -}}
{{- if ge $minorInt 32 -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Determine if CNPG should be enabled
Logic:
  1. If cnpg.enabled is explicitly set to false -> use legacy PostgreSQL
  2. If cnpg.enabled is true (or auto) -> check K8s version
     - K8s >= 1.32 -> use CNPG
     - K8s < 1.32 -> use legacy PostgreSQL with warning
*/}}
{{- define "kleidia-data.useCNPG" -}}
{{- if eq .Values.cnpg.enabled false -}}
false
{{- else -}}
{{- include "kleidia-data.cnpgSupported" . -}}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kleidia-data.labels" -}}
helm.sh/chart: {{ include "kleidia-data.chart" . }}
{{ include "kleidia-data.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kleidia-data.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kleidia-data.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

