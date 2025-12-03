{{/*
Expand the name of the chart.
*/}}
{{- define "otterscale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otterscale.fullname" -}}
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
{{- define "otterscale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otterscale.labels" -}}
helm.sh/chart: {{ include "otterscale.chart" . }}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otterscale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otterscale.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get nodeSelector from component or global
*/}}
{{- define "otterscale.nodeSelector" -}}
{{- $nodeSelector := .component.nodeSelector | default .global.nodeSelector | default dict }}
{{- if $nodeSelector }}
{{- toYaml $nodeSelector }}
{{- end }}
{{- end }}

{{/*
Get tolerations from component or global
*/}}
{{- define "otterscale.tolerations" -}}
{{- $tolerations := .component.tolerations | default .global.tolerations | default list }}
{{- if $tolerations }}
{{- toYaml $tolerations }}
{{- end }}
{{- end }}

{{/*
Get affinity from component or global
*/}}
{{- define "otterscale.affinity" -}}
{{- $affinity := .component.affinity | default .global.affinity | default dict }}
{{- if $affinity }}
{{- toYaml $affinity }}
{{- end }}
{{- end }}
